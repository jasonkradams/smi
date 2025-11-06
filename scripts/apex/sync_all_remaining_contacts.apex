// Sync all remaining contacts in batches
System.debug('=== SYNCING ALL REMAINING CONTACTS ===\n');

Integer totalSynced = 0;
Integer totalFailed = 0;
Integer batchCount = 0;
Integer maxBatches = 10; // Process up to 10 batches (4000 contacts max)

while (batchCount < maxBatches) {
    batchCount++;
    System.debug('--- Processing Batch #' + batchCount + ' ---');
    
    // Query next batch of contacts without User lookups
    List<Contact> contactsToSync = [
        SELECT Id, Name, Email, User_Lookup__c 
        FROM Contact 
        WHERE Email != NULL 
        AND User_Lookup__c = NULL
        ORDER BY CreatedDate
        LIMIT 400
    ];
    
    Integer batchSize = contactsToSync.size();
    System.debug('Found ' + batchSize + ' contacts in this batch');
    
    if (batchSize == 0) {
        System.debug('No more contacts to sync!');
        break;
    }
    
    // Process in sub-batches of 50
    Integer successCount = 0;
    Integer failureCount = 0;
    List<String> currentBatch = new List<String>();
    
    for (Integer i = 0; i < contactsToSync.size(); i++) {
        currentBatch.add(contactsToSync[i].Id);
        
        if (currentBatch.size() >= 50 || i == contactsToSync.size() - 1) {
            try {
                List<EventParticipantRedirectHelper.SyncResult> batchResults = 
                    EventParticipantRedirectHelper.bulkSyncContactsToUsers(currentBatch);
                
                for (EventParticipantRedirectHelper.SyncResult result : batchResults) {
                    if (result.success) {
                        successCount++;
                    } else {
                        failureCount++;
                    }
                }
            } catch (Exception e) {
                System.debug('ERROR processing batch: ' + e.getMessage());
                failureCount += currentBatch.size();
            }
            
            currentBatch.clear();
        }
    }
    
    totalSynced += successCount;
    totalFailed += failureCount;
    
    System.debug('Batch #' + batchCount + ' Results: ' + successCount + ' successful, ' + failureCount + ' failed');
    System.debug('Running totals: ' + totalSynced + ' synced, ' + totalFailed + ' failed');
    System.debug('SOQL queries used: ' + Limits.getQueries() + '/' + Limits.getLimitQueries() + '\n');
    
    // If no contacts were found, we're done
    if (batchSize < 400) {
        System.debug('Reached end of contacts to sync.');
        break;
    }
}

System.debug('========================================');
System.debug('SYNC COMPLETE');
System.debug('Total batches processed: ' + batchCount);
System.debug('Total contacts synced: ' + totalSynced);
System.debug('Total contacts failed: ' + totalFailed);
System.debug('Total contacts processed: ' + (totalSynced + totalFailed));
System.debug('Overall success rate: ' + ((totalSynced + totalFailed) > 0 ? ((totalSynced * 100.0 / (totalSynced + totalFailed))).setScale(2) + '%' : '0%'));
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('========================================');

