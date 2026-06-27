public with sharing class LayoutManagerService {
    
    @AuraEnabled
    public static String saveLayout(String objectApiName, String layoutJson, String status) {
        try {
            // 1. Find or create the Dynamic Layout record for this Object
            List<Dynamic_Layout__c> layouts = [SELECT Id, Name FROM Dynamic_Layout__c WHERE Object_API_Name__c = :objectApiName LIMIT 1];
            Dynamic_Layout__c layout;
            
            if (layouts.isEmpty()) {
                layout = new Dynamic_Layout__c(
                    Name = objectApiName + ' Layout',
                    Object_API_Name__c = objectApiName,
                    Status__c = status
                );
                insert layout;
            } else {
                layout = layouts[0];
                layout.Status__c = status;
                update layout;
            }
            
            // 2. Get highest version number
            Decimal nextVersion = 1;
            List<Layout_Version__c> versions = [SELECT Version_Number__c FROM Layout_Version__c WHERE Dynamic_Layout__c = :layout.Id ORDER BY Version_Number__c DESC LIMIT 1];
            if (!versions.isEmpty()) {
                nextVersion = versions[0].Version_Number__c + 1;
            }
            
            // 3. Create a new Layout Version
            Layout_Version__c newVersion = new Layout_Version__c(
                Dynamic_Layout__c = layout.Id,
                Version_Number__c = nextVersion,
                Configuration_JSON__c = layoutJson
            );
            insert newVersion;
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving layout: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getActiveLayout(String objectApiName) {
        List<Dynamic_Layout__c> layouts = [
            SELECT Id, (SELECT Configuration_JSON__c FROM Layout_Versions__r ORDER BY Version_Number__c DESC LIMIT 1)
            FROM Dynamic_Layout__c 
            WHERE Object_API_Name__c = :objectApiName AND Status__c = 'Published' LIMIT 1
        ];
        if (!layouts.isEmpty() && !layouts[0].Layout_Versions__r.isEmpty()) {
            return layouts[0].Layout_Versions__r[0].Configuration_JSON__c;
        }
        return null;
    }
}
