public class ScoringBatch implements Database.Batchable<SObject> {
    private String objectApiName;

    public ScoringBatch(String objectApiName) {
        this.objectApiName = objectApiName;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        List<Lead_Scoring_Rule__c> rules = ScoringService.getActiveRules(objectApiName);
        if (rules.isEmpty()) {
            return Database.getQueryLocator('SELECT Id FROM ' + objectApiName + ' LIMIT 0');
        }

        Set<String> fieldsToQuery = new Set<String>{'Id'};
        for (Lead_Scoring_Rule__c rule : rules) {
            fieldsToQuery.add(rule.Field_Api_Name__c);
        }

        List<String> fieldList = new List<String>(fieldsToQuery);
        String query = 'SELECT ' + String.join(fieldList, ', ') + ' FROM ' + objectApiName;
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        ScoringService.calculateScores(scope, objectApiName);
        
        // Strip out records where Score__c couldn't be updated (e.g. read-only, missing field)
        // by attempting update. Or we just update all.
        try {
            update scope;
        } catch(Exception e) {
            System.debug('Error updating batch ' + objectApiName + ' scores: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Scoring Batch for ' + objectApiName + ' completed.');
    }
}
