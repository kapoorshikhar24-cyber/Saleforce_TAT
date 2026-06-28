public with sharing class LayoutManagerService {
    
    @AuraEnabled
    public static Map<String, Object> getOrCreateLayout(String objectApiName) {
        try {
            List<Custom_Record_Page__c> layouts = [
                SELECT Id, Background_Image_URL__c, Layout_Config_JSON__c, Status__c 
                FROM Custom_Record_Page__c 
                WHERE Object_API_Name__c = :objectApiName LIMIT 1
            ];
            Custom_Record_Page__c layout;
            if (layouts.isEmpty()) {
                layout = new Custom_Record_Page__c(
                    Name = objectApiName + ' Layout',
                    Object_API_Name__c = objectApiName,
                    Status__c = 'Draft'
                );
                insert layout;
            } else {
                layout = layouts[0];
            }
            return new Map<String, Object>{
                'recordId' => layout.Id,
                'backgroundImageUrl' => layout.Background_Image_URL__c,
                'layoutConfigJson' => layout.Layout_Config_JSON__c,
                'status' => layout.Status__c
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String getUploadedImageUrl(String documentId) {
        try {
            ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :documentId AND IsLatest = true LIMIT 1];
            return '/sfc/servlet.shepherd/version/download/' + cv.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveLayout(String objectApiName, String layoutJson, String status) {
        try {
            Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(layoutJson);
            String bgUrl = (String)root.get('backgroundImageUrl');
            
            List<Custom_Record_Page__c> layouts = [SELECT Id, Name FROM Custom_Record_Page__c WHERE Object_API_Name__c = :objectApiName LIMIT 1];
            Custom_Record_Page__c layout;
            
            if (layouts.isEmpty()) {
                layout = new Custom_Record_Page__c(
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
            
            List<Layout_Section__c> oldSections = [SELECT Id FROM Layout_Section__c WHERE Custom_Record_Page__c = :layout.Id];
            if (!oldSections.isEmpty()) {
                List<Layout_Field__c> oldFields = [SELECT Id FROM Layout_Field__c WHERE Layout_Section__c IN :oldSections];
                if (!oldFields.isEmpty()) {
                    delete oldFields;
                }
                delete oldSections;
            }
            
            List<Object> sectionsJson = (List<Object>)root.get('sections');
            List<String> displayedFieldsList = new List<String>();
            
            if (sectionsJson != null) {
                Integer sectionOrder = 0;
                for (Object secObj : sectionsJson) {
                    Map<String, Object> secMap = (Map<String, Object>)secObj;
                    String secName = (String)secMap.get('name');
                    Integer columns = secMap.containsKey('columns') ? (Integer)secMap.get('columns') : 2;
                    Integer width = secMap.containsKey('width') ? (Integer)secMap.get('width') : 12;
                    Boolean scroll = secMap.containsKey('horizontalScroll') ? (Boolean)secMap.get('horizontalScroll') : false;
                    
                    Layout_Section__c parentSection = new Layout_Section__c(
                        Custom_Record_Page__c = layout.Id,
                        Section_Name__c = secName,
                        Display_Order__c = sectionOrder++,
                        Number_of_Columns__c = columns,
                        Width__c = width,
                        Horizontal_Scroll__c = scroll
                    );
                    insert parentSection;
                    
                    insertFields(secMap.get('fields'), parentSection.Id, displayedFieldsList);
                    
                    // Handle Subsections
                    List<Object> subJson = (List<Object>)secMap.get('subsections');
                    if (subJson != null) {
                        Integer subOrder = 0;
                        for (Object subObj : subJson) {
                            Map<String, Object> subMap = (Map<String, Object>)subObj;
                            String subName = (String)subMap.get('name');
                            Integer subCols = subMap.containsKey('columns') ? (Integer)subMap.get('columns') : 2;
                            Integer subWidth = subMap.containsKey('width') ? (Integer)subMap.get('width') : 12;
                            Boolean subScroll = subMap.containsKey('horizontalScroll') ? (Boolean)subMap.get('horizontalScroll') : false;
                            
                            Layout_Section__c subSection = new Layout_Section__c(
                                Custom_Record_Page__c = layout.Id,
                                Parent_Section__c = parentSection.Id,
                                Section_Name__c = subName,
                                Display_Order__c = subOrder++,
                                Number_of_Columns__c = subCols,
                                Width__c = subWidth,
                                Horizontal_Scroll__c = subScroll
                            );
                            insert subSection;
                            
                            insertFields(subMap.get('fields'), subSection.Id, displayedFieldsList);
                        }
                    }
                }
            }
            
            layout.Displayed_Fields__c = String.join(displayedFieldsList, ', ');
            layout.Layout_Config_JSON__c = layoutJson;
            update layout;
            
            Decimal nextVersion = 1;
            List<Layout_Version__c> versions = [SELECT Version_Number__c FROM Layout_Version__c WHERE Custom_Record_Page__c = :layout.Id ORDER BY Version_Number__c DESC LIMIT 1];
            if (!versions.isEmpty()) {
                nextVersion = versions[0].Version_Number__c + 1;
            }
            
            Layout_Version__c newVersion = new Layout_Version__c(
                Custom_Record_Page__c = layout.Id,
                Version_Number__c = nextVersion,
                Configuration_JSON__c = layoutJson
            );
            insert newVersion;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving layout: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static void insertFields(Object fieldsObj, Id sectionId, List<String> displayedFieldsList) {
        List<Object> fieldsJson = (List<Object>)fieldsObj;
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
                    Layout_Section__c = sectionId,
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

    @AuraEnabled(cacheable=true)
    public static String getActiveLayout(String objectApiName) {
        try {
            List<Custom_Record_Page__c> layouts = [
                SELECT Id, Background_Image_URL__c 
                FROM Custom_Record_Page__c 
                WHERE Object_API_Name__c = :objectApiName AND Status__c = 'Published' LIMIT 1
            ];
            if (layouts.isEmpty()) {
                return null;
            }
            Custom_Record_Page__c layout = layouts[0];
            
            List<Layout_Section__c> allSections = [
                SELECT Id, Section_Name__c, Number_of_Columns__c, Parent_Section__c, Width__c, Horizontal_Scroll__c,
                       (SELECT Field_API_Name__c, Custom_Label__c, Required__c, Read_Only__c FROM Layout_Fields__r ORDER BY Display_Order__c ASC)
                FROM Layout_Section__c 
                WHERE Custom_Record_Page__c = :layout.Id 
                ORDER BY Display_Order__c ASC
            ];
            
            Map<String, Object> layoutMap = new Map<String, Object>();
            layoutMap.put('backgroundImageUrl', layout.Background_Image_URL__c);
            
            Map<Id, Map<String, Object>> parentMap = new Map<Id, Map<String, Object>>();
            List<Map<String, Object>> sectionsList = new List<Map<String, Object>>();
            
            for (Layout_Section__c sec : allSections) {
                if (sec.Parent_Section__c == null) {
                    Map<String, Object> secMap = new Map<String, Object>();
                    secMap.put('id', sec.Id);
                    secMap.put('name', sec.Section_Name__c);
                    secMap.put('columns', sec.Number_of_Columns__c);
                    secMap.put('width', sec.Width__c != null ? sec.Width__c : 12);
                    secMap.put('horizontalScroll', sec.Horizontal_Scroll__c != null ? sec.Horizontal_Scroll__c : false);
                    secMap.put('fields', getFieldsList(sec.Layout_Fields__r));
                    secMap.put('subsections', new List<Object>());
                    parentMap.put(sec.Id, secMap);
                    sectionsList.add(secMap);
                }
            }
            
            for (Layout_Section__c sec : allSections) {
                if (sec.Parent_Section__c != null && parentMap.containsKey(sec.Parent_Section__c)) {
                    Map<String, Object> subMap = new Map<String, Object>();
                    subMap.put('id', sec.Id);
                    subMap.put('name', sec.Section_Name__c);
                    subMap.put('columns', sec.Number_of_Columns__c);
                    subMap.put('width', sec.Width__c != null ? sec.Width__c : 12);
                    subMap.put('horizontalScroll', sec.Horizontal_Scroll__c != null ? sec.Horizontal_Scroll__c : false);
                    subMap.put('fields', getFieldsList(sec.Layout_Fields__r));
                    
                    Map<String, Object> parentSec = parentMap.get(sec.Parent_Section__c);
                    List<Object> subs = (List<Object>)parentSec.get('subsections');
                    subs.add(subMap);
                }
            }
            
            layoutMap.put('sections', sectionsList);
            return JSON.serialize(layoutMap);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading layout: ' + e.getMessage());
        }
    }

    private static List<Map<String, Object>> getFieldsList(List<Layout_Field__c> fields) {
        List<Map<String, Object>> fieldsList = new List<Map<String, Object>>();
        for (Layout_Field__c fld : fields) {
            Map<String, Object> fldMap = new Map<String, Object>();
            fldMap.put('apiName', fld.Field_API_Name__c);
            fldMap.put('label', fld.Custom_Label__c);
            fldMap.put('required', fld.Required__c);
            fldMap.put('readOnly', fld.Read_Only__c);
            fieldsList.add(fldMap);
        }
        return fieldsList;
    }
}
