// Backfill Contact.User_Lookup__c for all event participants where the field is null.
// Safe to run multiple times — contacts already synced are skipped by bulkSyncContactsToUsers.
//
// Run with: sf apex run --file scripts/apex/backfill-contact-user-sync.apex --target-org smi

// Before count
List<Contact> beforeUnsynced = [
    SELECT Id, Name, Email
    FROM Contact
    WHERE Id IN (SELECT Contact__c FROM Event_Participant__c WHERE Event_Registration__c != null)
    AND User_Lookup__c = null
    AND Email != null
];
System.debug('Unsynced participant contacts BEFORE: ' + beforeUnsynced.size());

// Collect IDs
List<String> contactIds = new List<String>();
for (Contact c : beforeUnsynced) {
    contactIds.add(c.Id);
}

if (contactIds.isEmpty()) {
    System.debug('Nothing to sync — all participant contacts already have User_Lookup__c set.');
} else {
    System.debug('Syncing ' + contactIds.size() + ' contacts...');

    List<EventParticipantRedirectHelper.SyncResult> results =
        EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);

    Integer successCount = 0;
    Integer failCount = 0;
    for (EventParticipantRedirectHelper.SyncResult r : results) {
        if (r.success) {
            successCount++;
        } else {
            System.debug('No User match found for contactId: ' + r.contactId);
            failCount++;
        }
    }

    System.debug('Sync complete. Success: ' + successCount + ', No match found: ' + failCount);

    // After count (contacts still null = no User record with matching email exists)
    List<Contact> afterUnsynced = [
        SELECT Id, Name, Email
        FROM Contact
        WHERE Id IN (SELECT Contact__c FROM Event_Participant__c WHERE Event_Registration__c != null)
        AND User_Lookup__c = null
        AND Email != null
    ];
    System.debug('Unsynced participant contacts AFTER: ' + afterUnsynced.size() + ' (these have no matching User record)');
}
