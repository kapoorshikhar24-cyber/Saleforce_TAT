public with sharing class ScoringController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFields(String objectApiName) {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        
        try {
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectApiName);
            if (targetType == null) {
                return fieldList;
            }
            
            Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
            
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                if (dfr.isAccessible()) {
                    Map<String, String> fieldInfo = new Map<String, String>();
                    fieldInfo.put('label', dfr.getLabel());
                    fieldInfo.put('value', dfr.getName());
                    fieldInfo.put('type', String.valueOf(dfr.getType()));
                    fieldList.add(fieldInfo);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        return fieldList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead_Scoring_Rule__c> getScoringRules(String objectApiName) {
        return ScoringService.getActiveRules(objectApiName);
    }

    @AuraEnabled
    public static void saveRule(Lead_Scoring_Rule__c rule) {
        try {
            upsert rule;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        try {
            delete [SELECT Id FROM Lead_Scoring_Rule__c WHERE Id = :ruleId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void triggerBatchRecalculation(String objectApiName) {
        try {
            ScoringBatch batch = new ScoringBatch(objectApiName);
            Database.executeBatch(batch, 200);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static ScoringService.ScoreResult getScoreDetails(Id recordId, String objectApiName) {
        if (String.isBlank(objectApiName)) {
            // Default to Lead if somehow missing, or just return empty
            return new ScoringService.ScoreResult();
        }
        
        List<Lead_Scoring_Rule__c> rules = ScoringService.getActiveRules(objectApiName);
        if (rules.isEmpty()) return new ScoringService.ScoreResult();

        Set<String> fieldsToQuery = new Set<String>();
        for (Lead_Scoring_Rule__c rule : rules) {
            fieldsToQuery.add(rule.Field_Api_Name__c);
        }

        List<String> fieldList = new List<String>(fieldsToQuery);
        String query = 'SELECT Id, ' + String.join(fieldList, ', ') + ' FROM ' + objectApiName + ' WHERE Id = :recordId';
        
        List<SObject> records = Database.query(query);
        if (records.isEmpty()) return new ScoringService.ScoreResult();

        return ScoringService.evaluateRules(records[0], rules);
    }
}
