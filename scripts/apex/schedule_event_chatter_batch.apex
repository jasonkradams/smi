// Schedule the Event Chatter Batch Posting job to run every 60 minutes (hourly)
// This script should be run once to set up the scheduled job

System.debug('=== SCHEDULING EVENT CHATTER BATCH POSTING ===');

// Cron expression for every hour (every 60 minutes)
// Format: Second Minute Hour Day_of_month Month Day_of_week Year
// 0 0 * * * ? = Every hour at minute 0, second 0
String cronExpr = '0 0 * * * ?';

// Check if job already exists
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Event Chatter Batch Posting - Hourly'
];

if (!existingJobs.isEmpty()) {
    System.debug('Job already exists. Deleting existing job...');
    for (CronTrigger ct : existingJobs) {
        System.abortJob(ct.Id);
    }
}

// Schedule the batch job
EventChatterBatchPoster batch = new EventChatterBatchPoster();
String jobId = System.schedule('Event Chatter Batch Posting - Hourly', cronExpr, batch);

System.debug('Job scheduled successfully!');
System.debug('Job ID: ' + jobId);
System.debug('Cron Expression: ' + cronExpr);
System.debug('Next Fire Time: ' + [
    SELECT NextFireTime
    FROM CronTrigger
    WHERE Id = :jobId
].NextFireTime);

System.debug('=== SCHEDULING COMPLETE ===');

