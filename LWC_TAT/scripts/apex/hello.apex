// To schedule the SLA Notification Batch to run frequently, highlight this code 
// and select "SFDX: Execute Anonymous Apex with Currently Selected Text"

// Salesforce Cron Expressions do not support "every X minutes" in a single string, 
// so we schedule 4 separate jobs at 0, 15, 30, and 45 minutes past the hour.

String job1 = '0 0 * * * ?';
System.schedule('SLA Notification Batch - 00 Mins', job1, new LeadSlaNotificationBatch());

String job2 = '0 15 * * * ?';
System.schedule('SLA Notification Batch - 15 Mins', job2, new LeadSlaNotificationBatch());

String job3 = '0 30 * * * ?';
System.schedule('SLA Notification Batch - 30 Mins', job3, new LeadSlaNotificationBatch());

String job4 = '0 45 * * * ?';
System.schedule('SLA Notification Batch - 45 Mins', job4, new LeadSlaNotificationBatch());

System.debug('SLA Notification Batch has been successfully scheduled to run every 15 minutes!');