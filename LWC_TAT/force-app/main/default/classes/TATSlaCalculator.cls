public class TATSlaCalculator {

    @TestVisible
    private static List<TAT_Configuration__mdt> mockConfigs;

    public class SlaRequest {
        @InvocableVariable(required=true label='Object API Name' description='API Name of the record object (e.g., Lead)')
        public String objectName;
        
        @InvocableVariable(required=true label='Profile Name' description='Name of the User Profile to evaluate rules against')
        public String profileName;
        
        @InvocableVariable(required=true label='Start Date/Time' description='The time from which SLA is calculated')
        public Datetime startDatetime;
    }

    public class SlaResult {
        @InvocableVariable(label='SLA Deadline' description='Tier 1 deadline')
        public Datetime slaDeadline;
        
        @InvocableVariable(label='Tier 2 Deadline' description='Tier 2 deadline')
        public Datetime slaTier2Deadline;
        
        @InvocableVariable(label='Tier 3 Deadline' description='Tier 3 deadline')
        public Datetime slaTier3Deadline;
        
        @InvocableVariable(label='Has Error' description='True if configuration was not found')
        public Boolean hasError;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
    
    private static Long getMilliseconds(Decimal val, String unit) {
        if (val == null) return 0;
        if (String.isBlank(unit)) unit = 'Minutes';
        
        if (unit.equalsIgnoreCase('Days')) {
            return (Long)(val * 24 * 60 * 60 * 1000);
        } else if (unit.equalsIgnoreCase('Hours')) {
            return (Long)(val * 60 * 60 * 1000);
        } else if (unit.equalsIgnoreCase('Seconds')) {
            return (Long)(val * 1000);
        } else {
            return (Long)(val * 60 * 1000); // Default to Minutes
        }
    }

    @InvocableMethod(label='Calculate TAT SLA Deadlines' description='Calculates the SLA deadlines for all 3 Tiers considering Business Hours')
    public static List<SlaResult> calculateDeadline(List<SlaRequest> requests) {
        List<SlaResult> results = new List<SlaResult>();
        
        Set<String> objectNames = new Set<String>();
        for (SlaRequest req : requests) {
            if (String.isNotBlank(req.objectName)) {
                objectNames.add(req.objectName);
            }
        }
        
        List<TAT_Configuration__mdt> configs;
        if (Test.isRunningTest() && mockConfigs != null) {
            configs = mockConfigs;
        } else {
            configs = [
                SELECT Object_Name__c, Profile_Name__c, SLA_Value__c, SLA_Unit__c, Business_Hours_Name__c,
                       Tier_2_SLA_Value__c, Tier_2_SLA_Unit__c, Tier_3_SLA_Value__c, Tier_3_SLA_Unit__c
                FROM TAT_Configuration__mdt
                WHERE Object_Name__c IN :objectNames
            ];
        }
        
        Map<String, TAT_Configuration__mdt> configMap = new Map<String, TAT_Configuration__mdt>();
        for (TAT_Configuration__mdt conf : configs) {
            String key = conf.Object_Name__c.toLowerCase() + '-' + (String.isNotBlank(conf.Profile_Name__c) ? conf.Profile_Name__c.toLowerCase() : 'default');
            configMap.put(key, conf);
        }
        
        Set<String> bhNames = new Set<String>();
        for (TAT_Configuration__mdt conf : configs) {
            if (String.isNotBlank(conf.Business_Hours_Name__c)) {
                bhNames.add(conf.Business_Hours_Name__c);
            }
        }
        
        Map<String, Id> bhNameToIdMap = new Map<String, Id>();
        Id defaultBhId;
        try {
            defaultBhId = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1]?.Id;
        } catch(Exception e) {}
        
        if (!bhNames.isEmpty()) {
            for (BusinessHours bh : [SELECT Id, Name FROM BusinessHours WHERE Name IN :bhNames]) {
                bhNameToIdMap.put(bh.Name.toLowerCase(), bh.Id);
            }
        }
        
        for (SlaRequest req : requests) {
            SlaResult res = new SlaResult();
            res.hasError = false;
            
            try {
                String specificKey = req.objectName.toLowerCase() + '-' + (String.isNotBlank(req.profileName) ? req.profileName.toLowerCase() : '');
                String defaultKey = req.objectName.toLowerCase() + '-default';
                
                TAT_Configuration__mdt matchedConfig = configMap.get(specificKey);
                if (matchedConfig == null) {
                    matchedConfig = configMap.get(defaultKey);
                }
                
                if (matchedConfig == null) {
                    res.hasError = true;
                    res.errorMessage = 'No TAT Configuration found for Object: ' + req.objectName;
                    results.add(res);
                    continue;
                }
                
                Id bhId = defaultBhId;
                if (String.isNotBlank(matchedConfig.Business_Hours_Name__c)) {
                    Id foundBhId = bhNameToIdMap.get(matchedConfig.Business_Hours_Name__c.toLowerCase());
                    if (foundBhId != null) {
                        bhId = foundBhId;
                    }
                }
                
                Long t1Ms = getMilliseconds(matchedConfig.SLA_Value__c, matchedConfig.SLA_Unit__c);
                Long t2Ms = getMilliseconds(matchedConfig.Tier_2_SLA_Value__c, matchedConfig.Tier_2_SLA_Unit__c);
                Long t3Ms = getMilliseconds(matchedConfig.Tier_3_SLA_Value__c, matchedConfig.Tier_3_SLA_Unit__c);
                
                if (bhId != null) {
                    res.slaDeadline = BusinessHours.add(bhId, req.startDatetime, t1Ms);
                    res.slaTier2Deadline = t2Ms > 0 ? BusinessHours.add(bhId, res.slaDeadline, t2Ms) : null;
                    res.slaTier3Deadline = t3Ms > 0 ? BusinessHours.add(bhId, res.slaTier2Deadline != null ? res.slaTier2Deadline : res.slaDeadline, t3Ms) : null;
                } else {
                    res.slaDeadline = req.startDatetime.addSeconds(Integer.valueOf(t1Ms / 1000));
                    res.slaTier2Deadline = t2Ms > 0 ? res.slaDeadline.addSeconds(Integer.valueOf(t2Ms / 1000)) : null;
                    res.slaTier3Deadline = t3Ms > 0 ? (res.slaTier2Deadline != null ? res.slaTier2Deadline.addSeconds(Integer.valueOf(t3Ms / 1000)) : res.slaDeadline.addSeconds(Integer.valueOf(t3Ms / 1000))) : null;
                }
                
            } catch (Exception e) {
                res.hasError = true;
                res.errorMessage = 'Error calculating SLA: ' + e.getMessage();
            }
            
            results.add(res);
        }
        
        return results;
    }
}
