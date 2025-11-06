// Sync first 400 contacts (regardless of current User_Lookup__c status)
// Uses the efficient bulkSyncContactsToUsers method for optimal performance
System.debug('Starting bulk Contact to User sync for first 400 contacts with emails...');

// Query first 400 contacts that have emails (regardless of User_Lookup__c status)
List<Contact> contactsToSync = [
    SELECT Id, Name, Email, User_Lookup__c 
    FROM Contact 
    WHERE Email != NULL
    ORDER BY CreatedDate
    LIMIT 400
];

Integer totalContacts = contactsToSync.size();
Integer alreadySynced = 0;
Integer needsSync = 0;

for (Contact c : contactsToSync) {
    if (c.User_Lookup__c != null) {
        alreadySynced++;
    } else {
        needsSync++;
    }
}

System.debug('Found ' + totalContacts + ' contacts with emails');
System.debug('  Already synced: ' + alreadySynced);
System.debug('  Needs sync: ' + needsSync);

if (needsSync == 0) {
    System.debug('All ' + totalContacts + ' contacts already have User lookups!');
    return;
}

// Extract contact IDs that need syncing
List<String> contactIdsToSync = new List<String>();
for (Contact c : contactsToSync) {
    if (c.User_Lookup__c == null) {
        contactIdsToSync.add(c.Id);
    }
}

System.debug('Syncing ' + contactIdsToSync.size() + ' contacts...');

Integer successCount = 0;
Integer failureCount = 0;
Integer totalProcessed = 0;
Integer batchSize = 50; // Optimal batch size for governor limits
List<String> currentBatch = new List<String>();

System.debug('Starting efficient bulk sync in batches of ' + batchSize + '...');

// Process in batches of 50 (optimal for governor limits)
for (Integer i = 0; i < contactIdsToSync.size(); i++) {
    currentBatch.add(contactIdsToSync[i]);
    totalProcessed++;
    
    // Process batch when it reaches batchSize or at end of list
    if (currentBatch.size() >= batchSize || i == contactIdsToSync.size() - 1) {
        System.debug('Processing batch of ' + currentBatch.size() + ' contacts (total: ' + totalProcessed + '/' + contactIdsToSync.size() + ')');
        
        try {
            // Use the new efficient bulk sync method
            List<EventParticipantRedirectHelper.SyncResult> batchResults = 
                EventParticipantRedirectHelper.bulkSyncContactsToUsers(currentBatch);
            
            for (EventParticipantRedirectHelper.SyncResult result : batchResults) {
                if (result.success) {
                    successCount++;
                } else {
                    failureCount++;
                }
            }
            
            System.debug('Batch completed: ' + batchResults.size() + ' contacts processed');
            System.debug('SOQL queries used: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
        } catch (Exception e) {
            System.debug('ERROR processing batch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            failureCount += currentBatch.size();
        }
        
        // Reset batch
        currentBatch.clear();
    }
}

System.debug('========================================');
System.debug('Bulk sync completed:');
System.debug('Total contacts with emails: ' + totalContacts);
System.debug('Already had User lookups: ' + alreadySynced);
System.debug('Contacts processed: ' + totalProcessed);
System.debug('Successful syncs: ' + successCount);
System.debug('Failed syncs: ' + failureCount);
System.debug('Success rate: ' + (totalProcessed > 0 ? ((successCount * 100.0 / totalProcessed)).setScale(2) + '%' : '0%'));
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('SOQL queries remaining: ' + (Limits.getLimitQueries() - Limits.getQueries()));
System.debug('========================================');

