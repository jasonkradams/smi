// Test with the 3 contacts from your debug log
List<String> testContacts = new List<String>{
    '003Um000004HocSIAS',  // Derrek Daniels
    '003Um00000jXt3pIAC', // Jordan Randall  
    '0032G00002sd32kQAA'  // Arika Kuhlmann
};

System.debug('Starting bulk sync test...');
List<EventParticipantRedirectHelper.SyncResult> results = 
    EventParticipantRedirectHelper.bulkSyncContactsToUsers(testContacts);

System.debug('SOQL queries used: ' + Limits.getQueries());

Integer synced = 0;
for (EventParticipantRedirectHelper.SyncResult result : results) {
    if (result.success) {
        synced++;
        System.debug('✓ Successfully synced contact: ' + result.contactId);
    } else {
        System.debug('✗ Failed to sync contact: ' + result.contactId);
    }
}

System.debug('Bulk sync test completed: ' + synced + '/' + results.size() + ' contacts synced');