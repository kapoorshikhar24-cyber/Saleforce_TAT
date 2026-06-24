public with sharing class LeadTriggerHandler {
    
    public static void handleBeforeInsert(List<Lead> newLeads) {
        LeadScoringService.calculateScores(newLeads);
    }
    
    public static void handleBeforeUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeadsMap) {
        List<Lead_Scoring_Rule__c> rules = LeadScoringService.getActiveRules();
        Set<String> scoringFields = new Set<String>();
        for (Lead_Scoring_Rule__c rule : rules) {
            scoringFields.add(rule.Field_Api_Name__c.toLowerCase());
        }
        
        List<Lead> leadsToCalculate = new List<Lead>();
        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadsMap.get(newLead.Id);
            Boolean shouldCalculate = false;
            
            if (oldLead == null) {
                shouldCalculate = true;
            } else {
                for (String fieldName : scoringFields) {
                    try {
                        if (newLead.get(fieldName) != oldLead.get(fieldName)) {
                            shouldCalculate = true;
                            break;
                        }
                    } catch (Exception e) {
                        shouldCalculate = true;
                        break;
                    }
                }
            }
            
            if (shouldCalculate) {
                leadsToCalculate.add(newLead);
            }
        }
        
        if (!leadsToCalculate.isEmpty()) {
            for (Lead ld : leadsToCalculate) {
                LeadScoringService.ScoreResult result = LeadScoringService.evaluateRules(ld, rules);
                ld.Lead_Score__c = result.totalScore;
            }
        }
    }
}
