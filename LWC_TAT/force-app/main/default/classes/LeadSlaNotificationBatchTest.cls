@isTest
private class LeadSlaNotificationBatchTest {
    @isTest
    static void testBatchExecutes() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Batch',
            Company = 'Test Co',
            SLA_Deadline__c = System.now().addHours(-1), // Expired
            SLA_Escalation_Tier__c = 0
        );
        insert testLead;
        
        Test.startTest();
        LeadSlaNotificationBatch batch = new LeadSlaNotificationBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        Lead queriedLead = [SELECT SLA_Escalation_Tier__c FROM Lead WHERE Id = :testLead.Id];
        Integer typeCount = [SELECT count() FROM CustomNotificationType LIMIT 1];
        if (typeCount > 0) {
            System.assertEquals(1, queriedLead.SLA_Escalation_Tier__c, 'Notification should escalate to Tier 1.');
        }
    }
}
