@isTest
private class LeadScoringControllerTest {

    @testSetup
    static void setup() {
        // Create test scoring rules
        List<Lead_Scoring_Rule__c> rules = new List<Lead_Scoring_Rule__c>{
            new Lead_Scoring_Rule__c(
                Field_Api_Name__c = 'LeadSource',
                Field_Label__c = 'Lead Source',
                Operator__c = 'Equals',
                Value__c = 'Web',
                Score__c = 15
            ),
            new Lead_Scoring_Rule__c(
                Field_Api_Name__c = 'AnnualRevenue',
                Field_Label__c = 'Annual Revenue',
                Operator__c = 'Greater_Than',
                Value__c = '1000000',
                Score__c = 30
            ),
            new Lead_Scoring_Rule__c(
                Field_Api_Name__c = 'Rating',
                Field_Label__c = 'Rating',
                Operator__c = 'Not_Equals',
                Value__c = 'Cold',
                Score__c = 10
            ),
            new Lead_Scoring_Rule__c(
                Field_Api_Name__c = 'Industry',
                Field_Label__c = 'Industry',
                Operator__c = 'Contains',
                Value__c = 'Tech',
                Score__c = 20
            ),
            new Lead_Scoring_Rule__c(
                Field_Api_Name__c = 'DoNotCall',
                Field_Label__c = 'Do Not Call',
                Operator__c = 'Equals',
                Value__c = 'true',
                Score__c = -5
            )
        };
        insert rules;

        // Create test Leads
        List<Lead> leads = new List<Lead>{
            new Lead(
                LastName = 'MatchingLead',
                Company = 'Tech Solutions LLC',
                LeadSource = 'Web',
                AnnualRevenue = 1500000,
                Rating = 'Hot',
                Industry = 'Technology',
                DoNotCall = true
            ),
            new Lead(
                LastName = 'ColdLead',
                Company = 'Old Corp',
                LeadSource = 'Phone Inquiry',
                AnnualRevenue = 50000,
                Rating = 'Cold',
                Industry = 'Manufacturing',
                DoNotCall = false
            )
        };
        insert leads;
    }

    @isTest
    static void testGetLeadFields() {
        Test.startTest();
        List<LeadScoringController.FieldWrapper> fields = LeadScoringController.getLeadFields();
        Test.stopTest();

        Assert.isFalse(fields.isEmpty(), 'Fields should be returned');
        
        Boolean foundLeadSource = false;
        for (LeadScoringController.FieldWrapper f : fields) {
            if (f.apiName == 'LeadSource') {
                foundLeadSource = true;
                Assert.areEqual('PICKLIST', f.type);
                Assert.isFalse(f.picklistValues.isEmpty());
                break;
            }
        }
        Assert.isTrue(foundLeadSource, 'Should find LeadSource field');
    }

    @isTest
    static void testGetScoringRules() {
        Test.startTest();
        List<Lead_Scoring_Rule__c> rules = LeadScoringController.getScoringRules();
        Test.stopTest();

        Assert.areEqual(5, rules.size(), 'Should return 5 rules');
    }

    @isTest
    static void testSaveAndDeleteRule() {
        Lead_Scoring_Rule__c newRule = new Lead_Scoring_Rule__c(
            Field_Api_Name__c = 'Country',
            Field_Label__c = 'Country',
            Operator__c = 'Equals',
            Value__c = 'US',
            Score__c = 25
        );

        Test.startTest();
        Lead_Scoring_Rule__c savedRule = LeadScoringController.saveRule(newRule);
        Assert.isNotNull(savedRule.Id);

        List<Lead_Scoring_Rule__c> rules = LeadScoringController.getScoringRules();
        Assert.areEqual(6, rules.size(), 'Should have 6 rules now');

        LeadScoringController.deleteRule(savedRule.Id);
        rules = LeadScoringController.getScoringRules();
        Assert.areEqual(5, rules.size(), 'Should have 5 rules after deletion');
        Test.stopTest();
    }

    @isTest
    static void testLeadTriggerAndEvaluation() {
        Lead matchLead = [SELECT Id, Lead_Score__c FROM Lead WHERE LastName = 'MatchingLead' LIMIT 1];
        Lead coldLead = [SELECT Id, Lead_Score__c FROM Lead WHERE LastName = 'ColdLead' LIMIT 1];

        Assert.areEqual(70, matchLead.Lead_Score__c, 'MatchingLead score should be 70');
        Assert.areEqual(0, coldLead.Lead_Score__c, 'ColdLead score should be 0');

        matchLead.Rating = 'Cold'; // This removes rule 3 match (-10 score)
        update matchLead;

        Lead updatedMatchLead = [SELECT Id, Lead_Score__c FROM Lead WHERE Id = :matchLead.Id];
        Assert.areEqual(60, updatedMatchLead.Lead_Score__c, 'MatchingLead score should be 60 after update');
    }

    @isTest
    static void testGetLeadScoreDetails() {
        Lead matchLead = [SELECT Id FROM Lead WHERE LastName = 'MatchingLead' LIMIT 1];

        Test.startTest();
        LeadScoringService.ScoreResult result = LeadScoringController.getLeadScoreDetails(matchLead.Id);
        Test.stopTest();

        Assert.areEqual(70, result.totalScore);
        Assert.areEqual(5, result.matches.size());

        LeadScoringService.RuleMatch firstMatch = result.matches[0];
        Assert.isNotNull(firstMatch.ruleId);
        Assert.isNotNull(firstMatch.fieldLabel);
        Assert.isNotNull(firstMatch.fieldApiName);
    }

    @isTest
    static void testRecalculateAllLeadsBatch() {
        Lead matchLead = [SELECT Id FROM Lead WHERE LastName = 'MatchingLead' LIMIT 1];
        
        Test.startTest();
        String resultMsg = LeadScoringController.recalculateAllLeads();
        Test.stopTest();

        Assert.isTrue(resultMsg.contains('Recalculation started'));
        
        Lead recalculatedLead = [SELECT Id, Lead_Score__c FROM Lead WHERE Id = :matchLead.Id];
        Assert.areEqual(70, recalculatedLead.Lead_Score__c, 'Recalculated score should be 70');
    }
}
