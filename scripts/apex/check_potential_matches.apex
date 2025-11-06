// Check for Contacts that might have matching Users but aren't synced
System.debug('=== CHECKING FOR POTENTIAL MATCHES ===\n');

// Get all contacts needing sync
List<Contact> contactsNeedingSync = [
    SELECT Id, Name, Email 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL 
    LIMIT 100
];

System.debug('Found ' + contactsNeedingSync.size() + ' contacts needing sync');

// Get all User emails, usernames, and federation identifiers
List<User> allUsers = [
    SELECT Id, Username, Email, FederationIdentifier, IsActive 
    FROM User 
    WHERE IsActive = true
    LIMIT 500
];

System.debug('Found ' + allUsers.size() + ' active Users\n');

// Build sets of all User identifiers
Set<String> userEmails = new Set<String>();
Set<String> userUsernames = new Set<String>();
Set<String> userFedIds = new Set<String>();

for (User u : allUsers) {
    if (u.Email != null) {
        userEmails.add(u.Email.toLowerCase());
    }
    if (u.Username != null) {
        userUsernames.add(u.Username.toLowerCase());
    }
    if (u.FederationIdentifier != null) {
        userFedIds.add(u.FederationIdentifier.toLowerCase());
    }
}

System.debug('User identifier sets:');
System.debug('  Unique Emails: ' + userEmails.size());
System.debug('  Unique Usernames: ' + userUsernames.size());
System.debug('  Unique Federation IDs: ' + userFedIds.size());
System.debug('');

// Check each contact for potential matches (case-insensitive)
Integer potentialMatches = 0;
for (Contact c : contactsNeedingSync) {
    if (c.Email != null) {
        String contactEmailLower = c.Email.toLowerCase();
        
        Boolean hasEmailMatch = userEmails.contains(contactEmailLower);
        Boolean hasUsernameMatch = userUsernames.contains(contactEmailLower);
        Boolean hasFedIdMatch = userFedIds.contains(contactEmailLower);
        
        if (hasEmailMatch || hasUsernameMatch || hasFedIdMatch) {
            potentialMatches++;
            System.debug('POTENTIAL MATCH: ' + c.Name);
            System.debug('  Contact Email: ' + c.Email);
            System.debug('  Email match: ' + hasEmailMatch);
            System.debug('  Username match: ' + hasUsernameMatch);
            System.debug('  FedId match: ' + hasFedIdMatch);
            
            // Find the actual matching User
            List<User> matches = [
                SELECT Id, Username, Email, FederationIdentifier, IsActive
                FROM User
                WHERE (Email != null AND Email = :c.Email)
                   OR (Username != null AND Username = :c.Email)
                   OR (FederationIdentifier != null AND FederationIdentifier = :c.Email)
                LIMIT 5
            ];
            
            if (matches.isEmpty()) {
                System.debug('  ⚠️  Case-sensitivity issue? Lowercase match found but exact query failed');
            } else {
                for (User u : matches) {
                    System.debug('  ✅ Found User: ' + u.Username + ' (Active: ' + u.IsActive + ')');
                }
            }
            System.debug('');
        }
    }
}

System.debug('Total potential matches found: ' + potentialMatches + ' out of ' + contactsNeedingSync.size() + ' contacts');

