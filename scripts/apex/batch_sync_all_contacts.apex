// Batch sync first 400 Contacts to their matching User records
// Matches Contact.Email (transformed) to User.FederationIdentifier
// Transformation: replace @ with _, append @spokanemountaineers.org
// Uses the efficient bulkSyncContactsToUsers method for optimal performance
System.debug('Starting efficient bulk Contact to User sync (first 400 contacts, Email->FederationIdentifier)...');

// First check if User_Lookup__c field exists
try {
    Contact testContact = [SELECT Id, User_Lookup__c FROM Contact LIMIT 1];
    System.debug('User_Lookup__c field exists on Contact object');
} catch (Exception e) {
    System.debug('ERROR: User_Lookup__c field does not exist: ' + e.getMessage());
    // Exit early if field doesn't exist
    return;
}

// Query first 400 contacts without User lookups that have Email
// Matching: Contact.Email (transformed) -> User.FederationIdentifier
List<Contact> contactsToSync = [
    SELECT Id, Name, Email, User_Lookup__c 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL
    ORDER BY CreatedDate
    LIMIT 400
];

Integer totalContacts = contactsToSync.size();
System.debug('Found ' + totalContacts + ' contacts to sync');

if (totalContacts == 0) {
    System.debug('No contacts need syncing. All contacts already have User lookups or no Email.');
    return;
}

Integer successCount = 0;
Integer failureCount = 0;
Integer totalProcessed = 0;
Integer batchSize = 50; // Optimal batch size for governor limits
List<String> currentBatch = new List<String>();

System.debug('Starting efficient bulk sync in batches of ' + batchSize + '...');

// Process in batches of 50 (optimal for governor limits)
for (Integer i = 0; i < contactsToSync.size(); i++) {
    Contact contact = contactsToSync[i];
    currentBatch.add(contact.Id);
    totalProcessed++;
    
    // Process batch when it reaches batchSize or at end of list
    if (currentBatch.size() >= batchSize || i == contactsToSync.size() - 1) {
        System.debug('Processing batch of ' + currentBatch.size() + ' contacts (total: ' + totalProcessed + '/' + totalContacts + ')');
        
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
            failureCount += currentBatch.size();
        }
        
        // Reset batch
        currentBatch.clear();
    }
}

System.debug('========================================');
System.debug('Efficient bulk sync completed:');
System.debug('Total contacts processed: ' + totalProcessed);
System.debug('Successful syncs: ' + successCount);
System.debug('Failed syncs: ' + failureCount);
System.debug('Success rate: ' + (totalProcessed > 0 ? ((successCount * 100.0 / totalProcessed)).setScale(2) + '%' : '0%'));
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('SOQL queries remaining: ' + (Limits.getLimitQueries() - Limits.getQueries()));
System.debug('========================================');
