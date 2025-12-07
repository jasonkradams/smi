/**
 * Batch class for posting event notifications to Chatter groups
 * 
 * Runs daily at 5am Pacific to collect all approved events that haven't been posted yet,
 * group them by activity group, and post one comprehensive message per group.
 * 
 * Processes any approved event where Chatter_Posted__c != true, ensuring no events
 * are missed even if they were approved outside the normal processing window.
 */
public class EventChatterBatchPoster implements Database.Batchable<SObject>, Schedulable {
    
    /**
     * Schedulable execute method - schedules the batch job
     */
    public void execute(SchedulableContext ctx) {
        EventChatterBatchPoster batch = new EventChatterBatchPoster();
        Database.executeBatch(batch, 200);
    }
    
    /**
     * Batch start method - queries all approved events that haven't been posted yet
     * 
     * IMPORTANT: This method requires a custom field to prevent duplicate processing:
     * - Field: Chatter_Posted__c (Checkbox) - Set to true after posting
     * 
     * This approach processes ANY approved event that hasn't been posted, regardless of
     * when it was approved. This ensures no events are missed, even if:
     * - The batch job was skipped or failed previously
     * - Events were approved before the field was added
     * - Events were approved outside normal processing windows
     * 
     * This prevents reprocessing events that were already posted, even if they're modified later.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('EventChatterBatchPoster: Querying all approved events not yet posted to Chatter');
        
        // Query events that:
        // 1. Are currently Approved
        // 2. Have an Activity Group
        // 3. Haven't been posted to Chatter yet (Chatter_Posted__c != true)
        return Database.getQueryLocator([
            SELECT Id, Name, Activity_Group__c, Start__c, Location__c, 
                   Chatter_Posted__c, Leader__c, Leader__r.Name
            FROM Event_Registration__c
            WHERE Status__c = 'Approved'
            AND Activity_Group__c != null
            AND (Chatter_Posted__c != true)
            ORDER BY Activity_Group__c, Start__c
        ]);
    }
    
    /**
     * Batch execute method - processes events, groups by activity group, and posts
     */
    public void execute(Database.BatchableContext bc, List<Event_Registration__c> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('EventChatterBatchPoster: No events to process in this batch');
            return;
        }
        
        System.debug('EventChatterBatchPoster: Processing ' + scope.size() + ' events');
        
        // Group events by Activity_Group__c
        Map<String, List<Event_Registration__c>> eventsByGroup = new Map<String, List<Event_Registration__c>>();
        
        for (Event_Registration__c event : scope) {
            String activityGroup = String.isNotBlank(event.Activity_Group__c) ? event.Activity_Group__c : 'Unknown';
            
            if (!eventsByGroup.containsKey(activityGroup)) {
                eventsByGroup.put(activityGroup, new List<Event_Registration__c>());
            }
            eventsByGroup.get(activityGroup).add(event);
        }
        
        System.debug('EventChatterBatchPoster: Grouped into ' + eventsByGroup.size() + ' activity groups');
        
        // Post to each activity group and mark events as posted
        List<Event_Registration__c> eventsToUpdate = new List<Event_Registration__c>();
        
        for (String activityGroupName : eventsByGroup.keySet()) {
            List<Event_Registration__c> groupEvents = eventsByGroup.get(activityGroupName);
            System.debug('EventChatterBatchPoster: Posting ' + groupEvents.size() + ' events to ' + activityGroupName);
            
            // Post to Chatter
            EventChatterPostHelper.postBatchToChatterGroup(activityGroupName, groupEvents);
            
            // Mark events as posted to prevent reprocessing
            for (Event_Registration__c event : groupEvents) {
                event.Chatter_Posted__c = true;
                eventsToUpdate.add(event);
            }
        }
        
        // Update all events to mark them as posted
        if (!eventsToUpdate.isEmpty()) {
            try {
                update eventsToUpdate;
                System.debug('EventChatterBatchPoster: Marked ' + eventsToUpdate.size() + ' events as posted');
            } catch (Exception e) {
                System.debug('EventChatterBatchPoster: Error updating Chatter_Posted__c: ' + e.getMessage());
                // Don't throw - posting succeeded, just tracking failed
            }
        }
    }
    
    /**
     * Batch finish method - logs completion
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed,
                TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        System.debug('EventChatterBatchPoster: Batch job completed');
        System.debug('Status: ' + job.Status);
        System.debug('Job items processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug('Number of errors: ' + job.NumberOfErrors);
    }
}

