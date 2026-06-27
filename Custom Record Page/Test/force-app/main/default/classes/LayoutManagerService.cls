public with sharing class LayoutManagerService {
    
    @AuraEnabled
    public static String saveLayout(String objectApiName, String layoutJson, String status) {
        try {
            // Parse JSON to extract backgroundImageUrl and fields
            Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(layoutJson);
            String bgUrl = (String)root.get('backgroundImageUrl');
            
            // 1. Find or create the Dynamic Layout record for this Object
            List<Dynamic_Layout__c> layouts = [SELECT Id, Name FROM Dynamic_Layout__c WHERE Object_API_Name__c = :objectApiName LIMIT 1];
            Dynamic_Layout__c layout;
            
            if (layouts.isEmpty()) {
                layout = new Dynamic_Layout__c(
                    Name = objectApiName + ' Layout',
                    Object_API_Name__c = objectApiName,
                    Status__c = status,
                    Background_Image_URL__c = bgUrl
                );
                insert layout;
            } else {
                layout = layouts[0];
                layout.Status__c = status;
                layout.Background_Image_URL__c = bgUrl;
                update layout;
            }
            
            // Delete existing sections (Master-Detail cascade deletes fields automatically)
            List<Layout_Section__c> oldSections = [SELECT Id FROM Layout_Section__c WHERE Dynamic_Layout__c = :layout.Id];
            if (!oldSections.isEmpty()) {
                delete oldSections;
            }
            
            // Process and insert Sections and Fields
            List<Object> sectionsJson = (List<Object>)root.get('sections');
            List<String> displayedFieldsList = new List<String>();
            
            if (sectionsJson != null) {
                Integer sectionOrder = 0;
                for (Object secObj : sectionsJson) {
                    Map<String, Object> secMap = (Map<String, Object>)secObj;
                    String secName = (String)secMap.get('name');
                    Integer columns = secMap.containsKey('columns') ? (Integer)secMap.get('columns') : 2;
                    
                    Layout_Section__c section = new Layout_Section__c(
                        Dynamic_Layout__c = layout.Id,
                        Section_Name__c = secName,
                        Display_Order__c = sectionOrder++,
                        Number_of_Columns__c = columns
                    );
                    insert section;
                    
                    List<Object> fieldsJson = (List<Object>)secMap.get('fields');
                    if (fieldsJson != null) {
                        List<Layout_Field__c> fieldsToInsert = new List<Layout_Field__c>();
                        Integer fieldOrder = 0;
                        for (Object fldObj : fieldsJson) {
                            Map<String, Object> fldMap = (Map<String, Object>)fldObj;
                            String apiName = (String)fldMap.get('apiName');
                            String label = (String)fldMap.get('label');
                            Boolean req = fldMap.containsKey('required') ? (Boolean)fldMap.get('required') : false;
                            Boolean ro = fldMap.containsKey('readOnly') ? (Boolean)fldMap.get('readOnly') : false;
                            
                            displayedFieldsList.add(apiName);
                            
                            fieldsToInsert.add(new Layout_Field__c(
                                Layout_Section__c = section.Id,
                                Field_API_Name__c = apiName,
                                Custom_Label__c = label,
                                Required__c = req,
                                Read_Only__c = ro,
                                Display_Order__c = fieldOrder++
                            ));
                        }
                        if (!fieldsToInsert.isEmpty()) {
                            insert fieldsToInsert;
                        }
                    }
                }
            }
            
            // Save flat displayed fields back to the layout record
            layout.Displayed_Fields__c = String.join(displayedFieldsList, ', ');
            layout.Layout_Config_JSON__c = layoutJson; // Storing full JSON backup
            update layout;
            
            // 2. Get highest version number
            Decimal nextVersion = 1;
            List<Layout_Version__c> versions = [SELECT Version_Number__c FROM Layout_Version__c WHERE Dynamic_Layout__c = :layout.Id ORDER BY Version_Number__c DESC LIMIT 1];
            if (!versions.isEmpty()) {
                nextVersion = versions[0].Version_Number__c + 1;
            }
            
            // 3. Create a new Layout Version for backup/history
            Layout_Version__c newVersion = new Layout_Version__c(
                Dynamic_Layout__c = layout.Id,
                Version_Number__c = nextVersion,
                Configuration_JSON__c = layoutJson
            );
            insert newVersion;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving layout: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getActiveLayout(String objectApiName) {
        try {
            List<Dynamic_Layout__c> layouts = [
                SELECT Id, Background_Image_URL__c 
                FROM Dynamic_Layout__c 
                WHERE Object_API_Name__c = :objectApiName AND Status__c = 'Published' LIMIT 1
            ];
            if (layouts.isEmpty()) {
                return null;
            }
            Dynamic_Layout__c layout = layouts[0];
            
            // Query Sections and their Fields relationally
            List<Layout_Section__c> sections = [
                SELECT Id, Section_Name__c, Number_of_Columns__c,
                       (SELECT Field_API_Name__c, Custom_Label__c, Required__c, Read_Only__c FROM Layout_Fields__r ORDER BY Display_Order__c ASC)
                FROM Layout_Section__c 
                WHERE Dynamic_Layout__c = :layout.Id 
                ORDER BY Display_Order__c ASC
            ];
            
            // Reconstruct JSON structure
            Map<String, Object> layoutMap = new Map<String, Object>();
            layoutMap.put('backgroundImageUrl', layout.Background_Image_URL__c);
            
            List<Map<String, Object>> sectionsList = new List<Map<String, Object>>();
            for (Layout_Section__c sec : sections) {
                Map<String, Object> secMap = new Map<String, Object>();
                secMap.put('id', sec.Id);
                secMap.put('name', sec.Section_Name__c);
                secMap.put('columns', sec.Number_of_Columns__c);
                
                List<Map<String, Object>> fieldsList = new List<Map<String, Object>>();
                for (Layout_Field__c fld : sec.Layout_Fields__r) {
                    Map<String, Object> fldMap = new Map<String, Object>();
                    fldMap.put('apiName', fld.Field_API_Name__c);
                    fldMap.put('label', fld.Custom_Label__c);
                    fldMap.put('required', fld.Required__c);
                    fldMap.put('readOnly', fld.Read_Only__c);
                    fieldsList.add(fldMap);
                }
                secMap.put('fields', fieldsList);
                sectionsList.add(secMap);
            }
            layoutMap.put('sections', sectionsList);
            
            return JSON.serialize(layoutMap);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading layout: ' + e.getMessage());
        }
    }
}
