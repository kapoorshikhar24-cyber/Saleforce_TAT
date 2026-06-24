@isTest
public class TATSlaCalculatorTest {

    @isTest
    static void testCalculateDeadlineMinutesWithoutBusinessHours() {
        // Prepare mock configurations
        TAT_Configuration__mdt mockConf = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = 'System Administrator',
            SLA_Value__c = 30,
            SLA_Unit__c = 'Minutes'
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{ mockConf };

        // Prepare request
        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator';
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly one result');
        System.assertEquals(false, results[0].hasError, 'Should not have error');
        System.assertEquals(req.startDatetime.addMinutes(30), results[0].slaDeadline, 'Deadline should be start time + 30 minutes');
    }

    @isTest
    static void testCalculateDeadlineHoursWithoutBusinessHours() {
        // Prepare mock configurations
        TAT_Configuration__mdt mockConf = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = 'System Administrator',
            SLA_Value__c = 2,
            SLA_Unit__c = 'Hours'
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{ mockConf };

        // Prepare request
        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator';
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly one result');
        System.assertEquals(false, results[0].hasError, 'Should not have error');
        System.assertEquals(req.startDatetime.addHours(2), results[0].slaDeadline, 'Deadline should be start time + 2 hours');
    }

    @isTest
    static void testCalculateDeadlineSecondsWithoutBusinessHours() {
        // Prepare mock configurations
        TAT_Configuration__mdt mockConf = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = 'System Administrator',
            SLA_Value__c = 45,
            SLA_Unit__c = 'Seconds'
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{ mockConf };

        // Prepare request
        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator';
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly one result');
        System.assertEquals(false, results[0].hasError, 'Should not have error');
        System.assertEquals(req.startDatetime.addSeconds(45), results[0].slaDeadline, 'Deadline should be start time + 45 seconds');
    }

    @isTest
    static void testCalculateDeadlineWithBusinessHours() {
        // Query active business hours to use in test
        BusinessHours defaultBh = [SELECT Id, Name FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        
        // Prepare mock configurations
        TAT_Configuration__mdt mockConf = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = 'System Administrator',
            SLA_Value__c = 1,
            SLA_Unit__c = 'Hours',
            Business_Hours_Name__c = defaultBh.Name
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{ mockConf };

        // Prepare request
        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator';
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].hasError);
        Datetime expectedDeadline = BusinessHours.add(defaultBh.Id, req.startDatetime, 1 * 60 * 60 * 1000);
        System.assertEquals(expectedDeadline, results[0].slaDeadline, 'Deadline should match BusinessHours.add addition');
    }

    @isTest
    static void testCalculateDeadlineDefaultFallback() {
        // Test default matching config fallback
        TAT_Configuration__mdt mockConf = new TAT_Configuration__mdt(
            Object_Name__c = 'Lead',
            Profile_Name__c = '', // default config
            SLA_Value__c = 5,
            SLA_Unit__c = 'Minutes'
        );
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>{ mockConf };

        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator'; // requests specific profile, should fall back to default
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].hasError);
        System.assertEquals(req.startDatetime.addMinutes(5), results[0].slaDeadline, 'Should fall back to default config if profile specific config is missing');
    }

    @isTest
    static void testCalculateDeadlineNoConfigError() {
        TATSlaCalculator.mockConfigs = new List<TAT_Configuration__mdt>();

        TATSlaCalculator.SlaRequest req = new TATSlaCalculator.SlaRequest();
        req.objectName = 'Lead';
        req.profileName = 'System Administrator';
        req.startDatetime = Datetime.newInstance(2026, 6, 23, 10, 0, 0);

        Test.startTest();
        List<TATSlaCalculator.SlaResult> results = TATSlaCalculator.calculateDeadline(new List<TATSlaCalculator.SlaRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].hasError, 'Should set error status if config not found');
        System.assert(results[0].errorMessage.contains('No TAT Configuration found'), 'Should include error message');
    }
}
