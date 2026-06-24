public with sharing class ScoringTriggerHandler {
    
    public static void handleScoring(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) return;
        
        String objectApiName = newRecords[0].getSObjectType().getDescribe().getName();
        List<Lead_Scoring_Rule__c> rules = ScoringService.getActiveRules(objectApiName);
        if (rules.isEmpty()) return;
        
        List<SObject> recordsToScore = new List<SObject>();
        
        if (oldMap == null) {
            // Insert context - score all
            recordsToScore.addAll(newRecords);
        } else {
            // Update context - score only if relevant fields changed
            Set<String> ruleFields = new Set<String>();
            for (Lead_Scoring_Rule__c rule : rules) {
                ruleFields.add(rule.Field_Api_Name__c);
            }
            
            for (SObject newRecord : newRecords) {
                SObject oldRecord = oldMap.get(newRecord.Id);
                Boolean needsScoring = false;
                
                for (String fieldName : ruleFields) {
                    try {
                        if (newRecord.get(fieldName) != oldRecord.get(fieldName)) {
                            needsScoring = true;
                            break;
                        }
                    } catch(Exception e) {
                        // Field might not be accessible
                    }
                }
                
                if (needsScoring) {
                    recordsToScore.add(newRecord);
                }
            }
        }
        
        if (!recordsToScore.isEmpty()) {
            ScoringService.calculateScores(recordsToScore, objectApiName);
        }
    }
}
