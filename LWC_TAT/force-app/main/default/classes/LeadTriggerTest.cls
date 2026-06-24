@isTest
private class LeadTriggerTest {
    @isTest
    static void testTriggerSetsSla() {
        // Mock the configuration in TATSlaCalculator
        TAT_Configuration__mdt mockConfig = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = '', // Test without specific profile match
            SLA_Value__c = 10,
            SLA_Unit__c = 'Minutes'
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{mockConfig};
        
        Test.startTest();
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Trigger',
            Company = 'Test Co'
        );
        insert testLead;
        Test.stopTest();
        
        Lead queriedLead = [SELECT SLA_Deadline__c FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, queriedLead.SLA_Deadline__c, 'SLA Deadline should be set by the trigger.');
    }
}
