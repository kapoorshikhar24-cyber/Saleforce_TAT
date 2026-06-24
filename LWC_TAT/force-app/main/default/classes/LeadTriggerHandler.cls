public class LeadTriggerHandler {
    private static String currentUserProfileName;
    
    public static void handleBeforeInsert(List<Lead> newLeads) {
        calculateSla(newLeads);
    }
    
    public static void handleBeforeUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        List<Lead> leadsToCalculate = new List<Lead>();
        for (Lead l : newLeads) {
            // Only calculate if SLA is empty
            if (l.SLA_Deadline__c == null) {
                leadsToCalculate.add(l);
            }
        }
        if (!leadsToCalculate.isEmpty()) {
            calculateSla(leadsToCalculate);
        }
    }
    
    private static void calculateSla(List<Lead> leadsToCalculate) {
        if (currentUserProfileName == null) {
            currentUserProfileName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1].Name;
        }
        
        List<TATSlaCalculator.SlaRequest> requests = new List<TATSlaCalculator.SlaRequest>();
        for (Lead l : leadsToCalculate) {
            TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
            req.objectName = 'Lead';
            req.profileName = currentUserProfileName;
            // Use CreatedDate if available, else use current time for before insert
            req.startDatetime = l.CreatedDate != null ? l.CreatedDate : System.now();
            requests.add(req);
        }
        
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(requests);
        
        for (Integer i = 0; i < leadsToCalculate.size(); i++) {
            if (!results[i].hasError && results[i].slaDeadline != null) {
                leadsToCalculate[i].SLA_Deadline__c = results[i].slaDeadline;
                leadsToCalculate[i].SLA_Tier_2_Deadline__c = results[i].slaTier2Deadline;
                leadsToCalculate[i].SLA_Tier_3_Deadline__c = results[i].slaTier3Deadline;
            } else if (results[i].hasError) {
                System.debug('SLA Calculation Error: ' + results[i].errorMessage);
            }
        }
    }
}
