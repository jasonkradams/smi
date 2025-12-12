/**
 * Script to schedule LoginHistorySyncScheduler to run daily.
 * 
 * This schedules the daily sync batch that:
 * 1. Syncs LoginHistory records to Fiscal_Year_Login_History__c
 * 2. Triggers LicenseShuffleBatch to optimize license assignments
 * 
 * Recommended schedule: 2:00 AM daily
 * 
 * Run this script in Anonymous Apex to schedule the job.
 */

System.debug('=== Scheduling LoginHistorySyncScheduler ===');
System.debug('Start time: ' + DateTime.now());

try {
    // Schedule to run daily at 2:00 AM
    // Cron expression: Seconds Minutes Hours Day_of_month Month Day_of_week Year
    // 0 0 2 * * ? = Every day at 2:00 AM
    String cronExpression = '0 0 2 * * ?';
    
    LoginHistorySyncScheduler scheduler = new LoginHistorySyncScheduler();
    String jobId = System.schedule('Login History Sync - Daily', cronExpression, scheduler);
    
    System.debug('SUCCESS: Scheduled job with ID: ' + jobId);
    System.debug('Job Name: Login History Sync - Daily');
    System.debug('Schedule: Daily at 2:00 AM');
    System.debug('');
    System.debug('To view scheduled jobs, run:');
    System.debug('SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State');
    System.debug('FROM CronTrigger');
    System.debug('WHERE CronJobDetail.Name = \'Login History Sync - Daily\'');
    
} catch (Exception e) {
    System.debug('ERROR: Failed to schedule job: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
    
    // Check if job already exists
    if (e.getMessage().contains('duplicate') || e.getMessage().contains('already exists')) {
        System.debug('');
        System.debug('Job may already be scheduled. To check existing jobs:');
        System.debug('SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State');
        System.debug('FROM CronTrigger');
        System.debug('WHERE CronJobDetail.Name LIKE \'%Login History Sync%\'');
        System.debug('');
        System.debug('To delete an existing job:');
        System.debug('CronTrigger job = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = \'Login History Sync - Daily\' LIMIT 1];');
        System.debug('System.abortJob(job.Id);');
    }
}

System.debug('=== Scheduling Complete ===');

