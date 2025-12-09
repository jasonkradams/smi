// Schedule the Event Chatter Batch Posting job to run every 60 minutes (hourly)
// IMPORTANT: This script MUST be run from Developer Console while logged in as sm-client@prolocity.com
// 
// Instructions:
// 1. In Salesforce Setup, go to Users
// 2. Find and click on "sm-client@prolocity.com"
// 3. Click "Login" button (this will log you in as that user)
// 4. Open Developer Console (from the gear icon menu)
// 5. Go to Debug > Open Execute Anonymous Window
// 6. Copy and paste this entire script
// 7. Check "Open Log" and click Execute
// 8. Verify the output shows the job was scheduled and the "Current User" is sm-client@prolocity.com

System.debug('=== SCHEDULING EVENT CHATTER BATCH POSTING ===');
System.debug('Current User: ' + UserInfo.getUserName());
System.debug('Current User ID: ' + UserInfo.getUserId());

// Verify we're running as the correct user
if (UserInfo.getUserName() != 'sm-client@prolocity.com') {
    System.debug('ERROR: Not running as sm-client@prolocity.com! Current user: ' + UserInfo.getUserName());
    System.debug('Please login as sm-client@prolocity.com and try again.');
    return;
}

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
        System.debug('Aborting existing job: ' + ct.Id);
        System.abortJob(ct.Id);
    }
}

// Schedule the batch job
EventChatterBatchPoster batch = new EventChatterBatchPoster();
String jobId = System.schedule('Event Chatter Batch Posting - Hourly', cronExpr, batch);

System.debug('Job scheduled successfully!');
System.debug('Job ID: ' + jobId);
System.debug('Cron Expression: ' + cronExpr);

CronTrigger newJob = [
    SELECT Id, NextFireTime, CreatedById, CreatedBy.Name
    FROM CronTrigger
    WHERE Id = :jobId
    LIMIT 1
];

System.debug('Next Fire Time: ' + newJob.NextFireTime);
System.debug('Scheduled by: ' + newJob.CreatedBy.Name + ' (' + newJob.CreatedById + ')');
System.debug('=== SCHEDULING COMPLETE ===');
System.debug('IMPORTANT: This job will run as user: ' + UserInfo.getUserName());

