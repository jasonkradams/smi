/**
 * Script to schedule LoginHistoryCleanupScheduler to run annually on May 1st.
 * 
 * This schedules the annual cleanup batch that:
 * - Deletes Fiscal_Year_Login_History__c records before February 1st of previous fiscal year
 * - Keeps exactly one full fiscal year of data (Feb 1 - Jan 31)
 * 
 * Schedule: May 1st at 3:00 AM (after fiscal year ends on Jan 31)
 * 
 * Run this script in Anonymous Apex to schedule the job.
 */

System.debug('=== Scheduling LoginHistoryCleanupScheduler ===');
System.debug('Start time: ' + DateTime.now());

try {
    // Schedule to run annually on May 1st at 3:00 AM
    // Cron expression: Seconds Minutes Hours Day_of_month Month Day_of_week Year
    // 0 0 3 1 5 ? = May 1st at 3:00 AM every year
    String cronExpression = '0 0 3 1 5 ?';
    
    LoginHistoryCleanupScheduler scheduler = new LoginHistoryCleanupScheduler();
    String jobId = System.schedule('Login History Cleanup - Annual', cronExpression, scheduler);
    
    System.debug('SUCCESS: Scheduled job with ID: ' + jobId);
    System.debug('Job Name: Login History Cleanup - Annual');
    System.debug('Schedule: May 1st at 3:00 AM (annually)');
    System.debug('');
    System.debug('To view scheduled jobs, run:');
    System.debug('SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State');
    System.debug('FROM CronTrigger');
    System.debug('WHERE CronJobDetail.Name = \'Login History Cleanup - Annual\'');
    
} catch (Exception e) {
    System.debug('ERROR: Failed to schedule job: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    
    // Check if job already exists
    if (e.getMessage().contains('duplicate') || e.getMessage().contains('already exists')) {
        System.debug('');
        System.debug('Job may already be scheduled. To check existing jobs:');
        System.debug('SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State');
        System.debug('FROM CronTrigger');
        System.debug('WHERE CronJobDetail.Name LIKE \'%Login History Cleanup%\'');
        System.debug('');
        System.debug('To delete an existing job:');
        System.debug('CronTrigger job = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = \'Login History Cleanup - Annual\' LIMIT 1];');
        System.debug('System.abortJob(job.Id);');
    }
}

System.debug('=== Scheduling Complete ===');

