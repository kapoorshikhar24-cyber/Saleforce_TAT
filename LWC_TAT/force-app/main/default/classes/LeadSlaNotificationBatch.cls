global class LeadSlaNotificationBatch implements Database.Batchable<sObject>, Schedulable {
    
    // Batchable method: Queries Leads with active SLA that haven't reached Tier 3
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Name, SLA_Deadline__c, SLA_Tier_2_Deadline__c, SLA_Tier_3_Deadline__c, SLA_Escalation_Tier__c 
            FROM Lead 
            WHERE SLA_Deadline__c != null 
              AND SLA_Escalation_Tier__c < 3 
              AND IsConverted = false
        ]);
    }
    
    // Batchable method: Processes records to send notifications
    global void execute(Database.BatchableContext BC, List<Lead> scope) {
        if (scope.isEmpty()) return;
        
        List<CustomNotificationType> notificationTypes = [SELECT Id FROM CustomNotificationType LIMIT 1];
        if (notificationTypes.isEmpty()) {
            System.debug('No Custom Notification Types found in the org.');
            return;
        }
        CustomNotificationType notificationType = notificationTypes[0];
        
        // Retrieve Config for Escalation Override and Owner Change Settings
        TAT_Configuration__mdt config;
        try {
            config = [SELECT Tier_3_Override_Username__c, Change_Owner_on_Escalation__c 
                      FROM TAT_Configuration__mdt 
                      WHERE Object_Name__c = 'Lead' 
                      LIMIT 1];
        } catch (Exception e) {}
        
        String tier3Override = config != null ? config.Tier_3_Override_Username__c : null;
        Boolean changeOwner = config != null && config.Change_Owner_on_Escalation__c == true;
        
        Id overrideUserId = null;
        if (String.isNotBlank(tier3Override)) {
            try {
                overrideUserId = [SELECT Id FROM User WHERE Username = :tier3Override LIMIT 1].Id;
            } catch (Exception e) {}
        }
        
        // Get Owner details (to resolve User Managers, avoiding polymorphic Lead.Owner issues)
        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : scope) {
            ownerIds.add(l.OwnerId);
        }
        Map<Id, User> usersMap = new Map<Id, User>([
            SELECT Id, ManagerId, Manager.ManagerId 
            FROM User 
            WHERE Id IN :ownerIds
        ]);
        
        DateTime now = System.now();
        List<Lead> leadsToUpdate = new List<Lead>();
        
        for (Lead l : scope) {
            Integer currentTier = l.SLA_Escalation_Tier__c != null ? (Integer)l.SLA_Escalation_Tier__c : 0;
            Integer newTier = currentTier;
            Id notifyUserId = null;
            
            Id ownerManagerId = null;
            Id ownerManagerManagerId = null;
            if (usersMap.containsKey(l.OwnerId)) {
                User u = usersMap.get(l.OwnerId);
                ownerManagerId = u.ManagerId;
                ownerManagerManagerId = u.Manager != null ? u.Manager.ManagerId : null;
            }
            
            // Calculate Thresholds from Lead Fields!
            DateTime tier1Threshold = l.SLA_Deadline__c;
            DateTime tier2Threshold = l.SLA_Tier_2_Deadline__c != null ? l.SLA_Tier_2_Deadline__c : l.SLA_Deadline__c.addMinutes(60);
            DateTime tier3Threshold = l.SLA_Tier_3_Deadline__c != null ? l.SLA_Tier_3_Deadline__c : tier2Threshold.addMinutes(60);
            
            // Determine if an escalation needs to happen based on time passed
            if (currentTier == 0 && now >= tier1Threshold) {
                notifyUserId = l.OwnerId;
                newTier = 1;
            } else if (currentTier == 1 && now >= tier2Threshold) {
                notifyUserId = ownerManagerId != null ? ownerManagerId : l.OwnerId; // Fallback to owner if no manager
                newTier = 2;
            } else if (currentTier == 2 && now >= tier3Threshold) {
                if (overrideUserId != null) {
                    notifyUserId = overrideUserId;
                } else if (ownerManagerManagerId != null) {
                    notifyUserId = ownerManagerManagerId;
                } else {
                    notifyUserId = ownerManagerId != null ? ownerManagerId : l.OwnerId; // Fallback
                }
                newTier = 3;
            }
            
            // If a new tier was reached, send the alert and update the record
            if (newTier > currentTier && notifyUserId != null) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('SLA Escalation Tier ' + newTier + ': ' + l.Name);
                notification.setBody('The SLA for this lead has expired and escalated to Tier ' + newTier + '. Please take immediate action!');
                notification.setNotificationTypeId(notificationType.Id);
                notification.setTargetId(l.Id);
                
                try {
                    notification.send(new Set<String>{notifyUserId});
                    l.SLA_Escalation_Tier__c = newTier;
                    
                    // Change Owner logic if enabled via metadata
                    if (changeOwner && newTier > 1 && l.OwnerId != notifyUserId) {
                        l.OwnerId = notifyUserId;
                    }
                    
                    leadsToUpdate.add(l);
                } catch (Exception e) {
                    System.debug('Error sending Tier ' + newTier + ' notification for Lead ' + l.Id + ': ' + e.getMessage());
                }
            }
        }
        
        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        // Optional logic after batch finishes
    }
    
    global void execute(SchedulableContext SC) {
        Database.executeBatch(new LeadSlaNotificationBatch(), 50);
    }
}
