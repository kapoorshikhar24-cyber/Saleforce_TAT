public with sharing class LeadScoringService {

    public class RuleMatch {
        @AuraEnabled public String ruleId { get; set; }
        @AuraEnabled public String fieldLabel { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String operator { get; set; }
        @AuraEnabled public String configuredValue { get; set; }
        @AuraEnabled public String actualValue { get; set; }
        @AuraEnabled public Integer score { get; set; }

        public RuleMatch(Lead_Scoring_Rule__c rule, Object actualVal) {
            this.ruleId = rule.Id;
            this.fieldLabel = rule.Field_Label__c;
            this.fieldApiName = rule.Field_Api_Name__c;
            this.operator = rule.Operator__c;
            this.configuredValue = rule.Value__c;
            this.actualValue = actualVal != null ? String.valueOf(actualVal) : '';
            this.score = Integer.valueOf(rule.Score__c);
        }
    }

    public class ScoreResult {
        @AuraEnabled public Integer totalScore { get; set; }
        @AuraEnabled public List<RuleMatch> matches { get; set; }

        public ScoreResult() {
            this.totalScore = 0;
            this.matches = new List<RuleMatch>();
        }
    }

    /**
     * Calculates the score for a list of leads using the current rules.
     * Updates the Lead_Score__c field on the leads.
     */
    public static void calculateScores(List<Lead> leads) {
        List<Lead_Scoring_Rule__c> rules = getActiveRules();
        if (rules.isEmpty()) {
            for (Lead ld : leads) {
                ld.Lead_Score__c = 0;
            }
            return;
        }

        for (Lead ld : leads) {
            ScoreResult result = evaluateRules(ld, rules);
            ld.Lead_Score__c = result.totalScore;
        }
    }

    /**
     * Evaluates a single Lead record against a list of rules.
     */
    public static ScoreResult evaluateRules(Lead ld, List<Lead_Scoring_Rule__c> rules) {
        ScoreResult result = new ScoreResult();
        for (Lead_Scoring_Rule__c rule : rules) {
            if (evaluateRule(ld, rule)) {
                Object actualVal = null;
                try {
                    actualVal = ld.get(rule.Field_Api_Name__c);
                } catch(Exception e) {
                    // Field might not be populated or queried
                }
                RuleMatch match = new RuleMatch(rule, actualVal);
                result.matches.add(match);
                result.totalScore += match.score;
            }
        }
        return result;
    }

    /**
     * Evaluates if a lead matches a specific rule.
     */
    public static Boolean evaluateRule(Lead ld, Lead_Scoring_Rule__c rule) {
        String fieldName = rule.Field_Api_Name__c;
        String op = rule.Operator__c;
        String ruleVal = rule.Value__c;

        Object leadValObj = null;
        try {
            leadValObj = ld.get(fieldName);
        } catch (Exception e) {
            // Field not loaded/queried
            return false;
        }

        if (leadValObj == null) {
            if (op == 'Not_Equals' && String.isNotBlank(ruleVal)) {
                return true;
            }
            if (op == 'Equals' && String.isBlank(ruleVal)) {
                return true;
            }
            return false;
        }

        String leadValStr = String.valueOf(leadValObj);

        // Perform comparison based on data type if numeric/date
        if (leadValObj instanceof Decimal || leadValObj instanceof Integer || leadValObj instanceof Double) {
            return evaluateNumeric(leadValObj, op, ruleVal);
        } else if (leadValObj instanceof Boolean) {
            return evaluateBoolean((Boolean)leadValObj, op, ruleVal);
        } else {
            // Default to string comparisons
            return evaluateString(leadValStr, op, ruleVal);
        }
    }

    private static Boolean evaluateNumeric(Object leadValObj, String op, String ruleVal) {
        Decimal leadNum = Decimal.valueOf(String.valueOf(leadValObj));
        Decimal ruleNum;
        try {
            ruleNum = Decimal.valueOf(ruleVal);
        } catch (Exception e) {
            return false; // Invalid configured number rule
        }

        if (op == 'Equals') {
            return leadNum == ruleNum;
        } else if (op == 'Not_Equals') {
            return leadNum != ruleNum;
        } else if (op == 'Greater_Than') {
            return leadNum > ruleNum;
        } else if (op == 'Less_Than') {
            return leadNum < ruleNum;
        }
        return false;
    }

    private static Boolean evaluateBoolean(Boolean leadBool, String op, String ruleVal) {
        Boolean ruleBool = Boolean.valueOf(ruleVal);
        if (op == 'Equals') {
            return leadBool == ruleBool;
        } else if (op == 'Not_Equals') {
            return leadBool != ruleBool;
        }
        return false;
    }

    private static Boolean evaluateString(String leadValStr, String op, String ruleVal) {
        if (leadValStr == null) leadValStr = '';
        if (ruleVal == null) ruleVal = '';

        leadValStr = leadValStr.trim();
        ruleVal = ruleVal.trim();

        if (op == 'Equals') {
            return leadValStr.equalsIgnoreCase(ruleVal);
        } else if (op == 'Not_Equals') {
            return !leadValStr.equalsIgnoreCase(ruleVal);
        } else if (op == 'Contains') {
            return leadValStr.toLowerCase().contains(ruleVal.toLowerCase());
        } else if (op == 'Greater_Than') {
            return leadValStr.toLowerCase().compareTo(ruleVal.toLowerCase()) > 0;
        } else if (op == 'Less_Than') {
            return leadValStr.toLowerCase().compareTo(ruleVal.toLowerCase()) < 0;
        }
        return false;
    }

    public static List<Lead_Scoring_Rule__c> getActiveRules() {
        return [SELECT Id, Field_Api_Name__c, Field_Label__c, Operator__c, Value__c, Score__c 
                FROM Lead_Scoring_Rule__c 
                ORDER BY Field_Label__c ASC, Score__c DESC];
    }
}
