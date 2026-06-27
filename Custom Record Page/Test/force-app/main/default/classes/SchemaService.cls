public with sharing class SchemaService {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllObjects() {
        List<Map<String, String>> objectsList = new List<Map<String, String>>();
        for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()) {
            Schema.DescribeSObjectResult describeResult = objTyp.getDescribe();
            if (describeResult.isCustom() || describeResult.isAccessible()) {
                Map<String, String> objMap = new Map<String, String>();
                objMap.put('label', describeResult.getLabel());
                objMap.put('value', describeResult.getName());
                objectsList.add(objMap);
            }
        }
        // Sort alphabetically
        objectsList.sort(); // Needs a custom sorter if we want label sort, but value sort happens automatically on simple list if string. For Maps, we sort in JS.
        return objectsList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getObjectFields(String objectApiName) {
        List<Map<String, Object>> fieldsList = new List<Map<String, Object>>();
        if (String.isBlank(objectApiName)) return fieldsList;
        
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Schema.SObjectType objType = schemaMap.get(objectApiName);
        if (objType == null) return fieldsList;
        
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            Map<String, Object> fMap = new Map<String, Object>();
            fMap.put('label', fieldDescribe.getLabel());
            fMap.put('apiName', fieldDescribe.getName());
            fMap.put('type', String.valueOf(fieldDescribe.getType()));
            fMap.put('isUpdateable', fieldDescribe.isUpdateable());
            fMap.put('isRequired', !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate());
            fieldsList.add(fMap);
        }
        return fieldsList;
    }
}
