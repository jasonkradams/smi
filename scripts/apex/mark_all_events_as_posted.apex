// Script to mark all existing Event_Registration__c records as already posted to Chatter
// Run this ONCE before deploying the batch job to prevent posting about old events
// 
// IMPORTANT: This should be run BEFORE the batch job is scheduled for the first time
// This ensures that only NEW events approved after rollout will be posted to Chatter

System.debug('Starting: Mark all existing events as posted to Chatter');
System.debug('This prevents the batch job from posting about events that were approved before this feature was implemented.');
System.debug('');

// Query all Event_Registration__c records (regardless of status)
// We'll update all of them to be safe
List<Event_Registration__c> allEvents = [
    SELECT Id, Name, Status__c, Chatter_Posted__c
    FROM Event_Registration__c
];

System.debug('Found ' + allEvents.size() + ' total Event_Registration__c records');

if (allEvents.isEmpty()) {
    System.debug('No events found. Nothing to update.');
} else {
    // Count how many need updating
    Integer needsUpdate = 0;
    Integer alreadyTrue = 0;
    Integer alreadyFalse = 0;
    
    for (Event_Registration__c event : allEvents) {
        if (event.Chatter_Posted__c == true) {
            alreadyTrue++;
        } else if (event.Chatter_Posted__c == false) {
            alreadyFalse++;
            needsUpdate++;
        } else {
            // null value - needs to be set
            needsUpdate++;
        }
    }
    
    System.debug('Current status:');
    System.debug('  Already set to true: ' + alreadyTrue);
    System.debug('  Set to false: ' + alreadyFalse);
    System.debug('  Null (will be set to true): ' + (needsUpdate - alreadyFalse));
    System.debug('  Total to update: ' + needsUpdate);
    System.debug('');
    
    if (needsUpdate == 0) {
        System.debug('All events are already marked as posted. No updates needed.');
    } else {
        // Update all events to Chatter_Posted__c = true
        List<Event_Registration__c> eventsToUpdate = new List<Event_Registration__c>();
        
        for (Event_Registration__c event : allEvents) {
            if (event.Chatter_Posted__c != true) {
                event.Chatter_Posted__c = true;
                eventsToUpdate.add(event);
            }
        }
        
        try {
            update eventsToUpdate;
            System.debug('✓ SUCCESS: Updated ' + eventsToUpdate.size() + ' events to Chatter_Posted__c = true');
            System.debug('');
            System.debug('All existing events are now marked as posted.');
            System.debug('The batch job will only process NEW events approved after this point.');
        } catch (DmlException e) {
            System.debug('✗ ERROR: Failed to update events: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Try to update in smaller batches to see which ones fail
            Integer successCount = 0;
            Integer failCount = 0;
            
            for (Event_Registration__c event : eventsToUpdate) {
                try {
                    update event;
                    successCount++;
                } catch (DmlException individualError) {
                    failCount++;
                    System.debug('Failed to update event ' + event.Id + ' (' + event.Name + '): ' + individualError.getMessage());
                }
            }
            
            System.debug('');
            System.debug('Partial results:');
            System.debug('  Successfully updated: ' + successCount);
            System.debug('  Failed: ' + failCount);
        }
    }
}

System.debug('');
System.debug('Script completed.');

