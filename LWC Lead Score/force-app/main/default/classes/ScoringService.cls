public with sharing class ScoringService {

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

    public static void calculateScores(List<SObject> records, String objectApiName) {
        if (records == null || records.isEmpty()) return;

        List<Lead_Scoring_Rule__c> rules = getActiveRules(objectApiName);
        if (rules.isEmpty()) {
            for (SObject record : records) {
                try {
                    record.put('Score__c', 0);
                } catch(Exception e) {
                    // Ignore if Score__c field doesn't exist
                }
            }
            return;
        }

        for (SObject record : records) {
            ScoreResult result = evaluateRules(record, rules);
            try {
                record.put('Score__c', result.totalScore);
            } catch(Exception e) {
                // Ignore if Score__c field doesn't exist
            }
        }
    }

    public static ScoreResult evaluateRules(SObject record, List<Lead_Scoring_Rule__c> rules) {
        ScoreResult result = new ScoreResult();
        for (Lead_Scoring_Rule__c rule : rules) {
            if (evaluateRule(record, rule)) {
                Object actualVal = null;
                try {
                    actualVal = record.get(rule.Field_Api_Name__c);
                } catch(Exception e) { }
                
                RuleMatch match = new RuleMatch(rule, actualVal);
                result.matches.add(match);
                result.totalScore += match.score;
            }
        }
        return result;
    }

    public static Boolean evaluateRule(SObject record, Lead_Scoring_Rule__c rule) {
        String fieldName = rule.Field_Api_Name__c;
        String op = rule.Operator__c;
        String ruleVal = rule.Value__c;

        Object recordValObj = null;
        try {
            recordValObj = record.get(fieldName);
        } catch (Exception e) {
            return false;
        }

        if (op == 'IsBlank') {
            return recordValObj == null || String.isBlank(String.valueOf(recordValObj));
        }
        if (op == 'IsNotBlank') {
            return recordValObj != null && String.isNotBlank(String.valueOf(recordValObj));
        }

        if (recordValObj == null) {
            if (op == 'Not_Equals' && String.isNotBlank(ruleVal)) return true;
            if (op == 'Equals' && String.isBlank(ruleVal)) return true;
            return false;
        }

        String recordValStr = String.valueOf(recordValObj);

        if (recordValObj instanceof Decimal || recordValObj instanceof Integer || recordValObj instanceof Double) {
            return evaluateNumeric(recordValObj, op, ruleVal);
        } else if (recordValObj instanceof Boolean) {
            return evaluateBoolean((Boolean)recordValObj, op, ruleVal);
        } else {
            return evaluateString(recordValStr, op, ruleVal);
        }
    }

    private static Boolean evaluateNumeric(Object recordValObj, String op, String ruleVal) {
        Decimal recordNum = Decimal.valueOf(String.valueOf(recordValObj));
        Decimal ruleNum;
        try {
            ruleNum = Decimal.valueOf(ruleVal);
        } catch (Exception e) {
            return false; 
        }

        if (op == 'Equals') return recordNum == ruleNum;
        else if (op == 'Not_Equals') return recordNum != ruleNum;
        else if (op == 'Greater_Than') return recordNum > ruleNum;
        else if (op == 'Less_Than') return recordNum < ruleNum;
        return false;
    }

    private static Boolean evaluateBoolean(Boolean recordBool, String op, String ruleVal) {
        Boolean ruleBool = Boolean.valueOf(ruleVal);
        if (op == 'Equals') return recordBool == ruleBool;
        else if (op == 'Not_Equals') return recordBool != ruleBool;
        return false;
    }

    private static Boolean evaluateString(String recordValStr, String op, String ruleVal) {
        if (recordValStr == null) recordValStr = '';
        if (ruleVal == null) ruleVal = '';

        recordValStr = recordValStr.trim();
        ruleVal = ruleVal.trim();

        if (op == 'Equals') return recordValStr.equalsIgnoreCase(ruleVal);
        else if (op == 'Not_Equals') return !recordValStr.equalsIgnoreCase(ruleVal);
        else if (op == 'Contains') return recordValStr.toLowerCase().contains(ruleVal.toLowerCase());
        else if (op == 'Greater_Than') return recordValStr.toLowerCase().compareTo(ruleVal.toLowerCase()) > 0;
        else if (op == 'Less_Than') return recordValStr.toLowerCase().compareTo(ruleVal.toLowerCase()) < 0;
        return false;
    }

    public static List<Lead_Scoring_Rule__c> getActiveRules(String objectApiName) {
        return [SELECT Id, Object_Api_Name__c, Field_Api_Name__c, Field_Label__c, Operator__c, Value__c, Score__c 
                FROM Lead_Scoring_Rule__c 
                WHERE Object_Api_Name__c = :objectApiName
                ORDER BY Field_Label__c ASC, Score__c DESC];
    }
}
