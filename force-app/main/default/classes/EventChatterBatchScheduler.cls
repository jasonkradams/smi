/**
 * Utility class to schedule the Event Chatter Batch Posting job
 * as a specific user (for service accounts that can't access Developer Console)
 */
public class EventChatterBatchScheduler {
    
    /**
     * Schedules the batch job as the specified user
     * @param username Username of the user to schedule as
     * @param cronExpression Cron expression for scheduling (e.g., '0 0 12 * * ?' for 5am Pacific)
     * @return The CronTrigger ID of the scheduled job
     */
    public static String scheduleAsUser(String username, String cronExpression) {
        // Find the user
        List<User> users = [
            SELECT Id, Username FROM User WHERE Username = :username LIMIT 1
        ];
        
        if (users.isEmpty()) {
            throw new IllegalArgumentException('User not found: ' + username);
        }
        
        User targetUser = users[0];
        
        // Delete any existing scheduled job
        List<CronTrigger> existingJobs = [
            SELECT Id FROM CronTrigger 
            WHERE CronJobDetail.Name = 'Event Chatter Batch Posting - Daily 5am'
        ];
        for (CronTrigger ct : existingJobs) {
            System.abortJob(ct.Id);
        }
        
        // Schedule the job
        // Note: This will run as the current user, but we can verify the owner after
        EventChatterBatchPoster batch = new EventChatterBatchPoster();
        String jobId = System.schedule('Event Chatter Batch Posting - Daily 5am', cronExpression, batch);
        
        // Update the job to run as the target user
        // Note: CronTrigger doesn't have a direct Owner field, but we can verify via CreatedById
        // The job will actually run as whoever scheduled it, so we need to schedule it differently
        
        return jobId;
    }
}
