trigger LeadTrigger on Lead (after insert, after update) {
    ScoringTriggerHandler.handleScoring(Trigger.new, Trigger.oldMap);
}
