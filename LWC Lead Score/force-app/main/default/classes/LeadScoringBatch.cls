public with sharing class LeadScoringBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Collect all fields referenced in active rules
        List<Lead_Scoring_Rule__c> rules = LeadScoringService.getActiveRules();
        Set<String> queryFields = new Set<String>{ 'id', 'lead_score__c' };
        for (Lead_Scoring_Rule__c rule : rules) {
            queryFields.add(rule.Field_Api_Name__c.toLowerCase());
        }
        String query = 'SELECT ' + String.join(new List<String>(queryFields), ', ') + ' FROM Lead';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        LeadScoringService.calculateScores(scope);
        // Avoid update if not changed (though standard DML in batch is simple)
        update scope;
    }
    
    public void finish(Database.BatchableContext bc) {
        // Optional batch post-processing logic
    }
}
