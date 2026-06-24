for(CronTrigger ct : [SELECT Id FROM CronTrigger]) {
    System.abortJob(ct.Id);
}
