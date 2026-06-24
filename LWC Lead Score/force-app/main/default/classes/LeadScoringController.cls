public with sharing class LeadScoringController {

    public class FieldWrapper implements Comparable {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String apiName { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public List<String> picklistValues { get; set; }

        public FieldWrapper(String label, String apiName, String type) {
            this.label = label;
            this.apiName = apiName;
            this.type = type;
            this.picklistValues = new List<String>();
        }

        public Integer compareTo(Object compareTo) {
            FieldWrapper other = (FieldWrapper)compareTo;
            return this.label.compareTo(other.label);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getLeadFields() {
        List<FieldWrapper> fields = new List<FieldWrapper>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult describe = fieldMap.get(fieldName).getDescribe();
            if (describe.isAccessible() && describe.isFilterable()) {
                String typeStr = String.valueOf(describe.getType()).toUpperCase();
                // Filter to supported data types
                if (typeStr == 'STRING' || typeStr == 'PICKLIST' || typeStr == 'BOOLEAN' || 
                    typeStr == 'INTEGER' || typeStr == 'DOUBLE' || typeStr == 'CURRENCY' || 
                    typeStr == 'PERCENT' || typeStr == 'DATE' || typeStr == 'DATETIME' || 
                    typeStr == 'EMAIL' || typeStr == 'PHONE' || typeStr == 'URL' || typeStr == 'COMBOBOX') {
                    
                    FieldWrapper wrapper = new FieldWrapper(describe.getLabel(), describe.getName(), typeStr);
                    if (typeStr == 'PICKLIST') {
                        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                            if (entry.isActive()) {
                                wrapper.picklistValues.add(entry.getValue());
                            }
                        }
                    }
                    fields.add(wrapper);
                }
            }
        }
        fields.sort();
        return fields;
    }

    @AuraEnabled
    public static List<Lead_Scoring_Rule__c> getScoringRules() {
        return LeadScoringService.getActiveRules();
    }

    @AuraEnabled
    public static Lead_Scoring_Rule__c saveRule(Lead_Scoring_Rule__c rule) {
        upsert rule;
        return rule;
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        delete [SELECT Id FROM Lead_Scoring_Rule__c WHERE Id = :ruleId];
    }

    @AuraEnabled
    public static LeadScoringService.ScoreResult getLeadScoreDetails(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID cannot be null.');
        }

        // Get active rules
        List<Lead_Scoring_Rule__c> rules = LeadScoringService.getActiveRules();
        
        // Build dynamic query for lead
        Set<String> queryFields = new Set<String>{ 'id', 'name', 'lead_score__c' };
        for (Lead_Scoring_Rule__c rule : rules) {
            queryFields.add(rule.Field_Api_Name__c.toLowerCase());
        }

        String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ') + ' FROM Lead WHERE Id = :leadId LIMIT 1';
        List<Lead> leads = Database.query(query);
        
        if (leads.isEmpty()) {
            throw new AuraHandledException('Lead record not found.');
        }

        Lead ld = leads[0];
        LeadScoringService.ScoreResult result = LeadScoringService.evaluateRules(ld, rules);
        
        // Save the score if it has changed
        if (ld.Lead_Score__c != result.totalScore) {
            ld.Lead_Score__c = result.totalScore;
            update ld;
        }

        return result;
    }

    @AuraEnabled
    public static String recalculateAllLeads() {
        try {
            LeadScoringBatch batch = new LeadScoringBatch();
            Id batchJobId = Database.executeBatch(batch, 200);
            return 'Recalculation started. Job ID: ' + batchJobId;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to start recalculation: ' + e.getMessage());
        }
    }
}
