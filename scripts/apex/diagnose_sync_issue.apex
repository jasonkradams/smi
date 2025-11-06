// Diagnostic script to investigate Contact-User sync issues
System.debug('=== CONTACT-USER SYNC DIAGNOSTIC ===\n');

// 1. Get statistics
Integer contactsNeedingSync = [SELECT COUNT() FROM Contact WHERE Email != NULL AND User_Lookup__c = NULL];
Integer contactsWithLookup = [SELECT COUNT() FROM Contact WHERE User_Lookup__c != NULL];
Integer totalContacts = [SELECT COUNT() FROM Contact];
Integer activeUsers = [SELECT COUNT() FROM User WHERE IsActive = true];
Integer totalUsers = [SELECT COUNT() FROM User];

System.debug('STATISTICS:');
System.debug('  Total Contacts: ' + totalContacts);
System.debug('  Contacts with User Lookup: ' + contactsWithLookup);
System.debug('  Contacts needing sync: ' + contactsNeedingSync);
System.debug('  Total Users: ' + totalUsers);
System.debug('  Active Users: ' + activeUsers);
System.debug('');

// 2. Sample contacts needing sync
List<Contact> sampleContacts = [SELECT Id, Name, Email FROM Contact WHERE Email != NULL AND User_Lookup__c = NULL LIMIT 5];
System.debug('SAMPLE CONTACTS NEEDING SYNC (' + sampleContacts.size() + '):');
for (Contact c : sampleContacts) {
    System.debug('  Contact: ' + c.Name);
    System.debug('    Email: ' + c.Email);
    System.debug('    Id: ' + c.Id);
    
    // Check for matching Users using the same logic as bulkSyncContactsToUsers
    Set<String> emailSet = new Set<String>{ c.Email };
    List<User> matchingUsers = [
        SELECT Id, Username, Email, FederationIdentifier, IsActive 
        FROM User 
        WHERE Email = :emailSet 
           OR Username = :emailSet 
           OR FederationIdentifier = :emailSet
        LIMIT 10
    ];
    
    System.debug('    Matching Users found: ' + matchingUsers.size());
    
    if (matchingUsers.isEmpty()) {
        System.debug('    ❌ NO MATCHES FOUND');
    } else {
        for (User u : matchingUsers) {
            String matchType = '';
            if (u.Username == c.Email) {
                matchType = 'Username match';
            } else if (u.FederationIdentifier == c.Email) {
                matchType = 'FederationIdentifier match';
            } else if (u.Email == c.Email) {
                matchType = 'Email match';
            }
            System.debug('    ✅ ' + matchType + ': ' + u.Username + ' (Active: ' + u.IsActive + ')');
        }
    }
    System.debug('');
}

// 3. Check if there are any Users with matching emails/username/fedId
if (!sampleContacts.isEmpty()) {
    Set<String> contactEmails = new Set<String>();
    for (Contact c : sampleContacts) {
        if (c.Email != null) {
            contactEmails.add(c.Email);
        }
    }
    
    List<User> allPotentiallyMatchingUsers = [
        SELECT Id, Username, Email, FederationIdentifier, IsActive 
        FROM User 
        WHERE Email IN :contactEmails 
           OR Username IN :contactEmails 
           OR FederationIdentifier IN :contactEmails
        LIMIT 20
    ];
    
    System.debug('ALL USERS MATCHING SAMPLE CONTACT EMAILS: ' + allPotentiallyMatchingUsers.size());
    for (User u : allPotentiallyMatchingUsers) {
        System.debug('  User: ' + u.Username);
        System.debug('    Email: ' + u.Email);
        System.debug('    FederationIdentifier: ' + u.FederationIdentifier);
        System.debug('    IsActive: ' + u.IsActive);
        System.debug('    Matches: ' + contactEmails.contains(u.Email) + ' (Email) | ' + contactEmails.contains(u.Username) + ' (Username) | ' + contactEmails.contains(u.FederationIdentifier) + ' (FedId)');
    }
}

// 4. Test the actual bulkSyncContactsToUsers method with sample contacts
if (!sampleContacts.isEmpty()) {
    System.debug('\n=== TESTING bulkSyncContactsToUsers METHOD ===');
    List<String> testContactIds = new List<String>();
    for (Contact c : sampleContacts) {
        testContactIds.add(c.Id);
    }
    
    System.debug('Testing with ' + testContactIds.size() + ' contacts...');
    List<EventParticipantRedirectHelper.SyncResult> results = 
        EventParticipantRedirectHelper.bulkSyncContactsToUsers(testContactIds);
    
    Integer successCount = 0;
    Integer failCount = 0;
    for (EventParticipantRedirectHelper.SyncResult r : results) {
        if (r.success) {
            successCount++;
            System.debug('  ✅ Contact ' + r.contactId + ' synced successfully');
        } else {
            failCount++;
            System.debug('  ❌ Contact ' + r.contactId + ' failed to sync');
        }
    }
    
    System.debug('Results: ' + successCount + ' successful, ' + failCount + ' failed');
    System.debug('SOQL queries used: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
}

System.debug('\n=== DIAGNOSTIC COMPLETE ===');

