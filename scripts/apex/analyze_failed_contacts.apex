// Analyze failed contacts to understand why they didn't match
System.debug('=== ANALYZING FAILED CONTACTS ===\n');

List<Contact> failedContacts = [
    SELECT Id, Name, Email 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL 
    LIMIT 20
];

System.debug('Total failed contacts analyzed: ' + failedContacts.size() + '\n');

Integer emailMatches = 0;
Integer fedIdMatches = 0;
Integer usernameMatches = 0;
Integer noMatches = 0;

for (Contact c : failedContacts) {
    System.debug('Contact: ' + c.Name);
    System.debug('  Email: ' + c.Email);
    
    // Check for matching User.Email
    List<User> emailMatch = [
        SELECT Id, Username, Email 
        FROM User 
        WHERE Email = :c.Email 
        LIMIT 1
    ];
    
    // Check for matching User.FederationIdentifier
    String fedId = c.Email.replace('@', '_') + '@spokanemountaineers.org';
    List<User> fedMatch = [
        SELECT Id, Username, FederationIdentifier 
        FROM User 
        WHERE FederationIdentifier = :fedId 
        LIMIT 1
    ];
    
    // Check for matching User.Username (email.smi pattern)
    String usernameWithSmi = c.Email + '.smi';
    List<User> usernameMatch = [
        SELECT Id, Username 
        FROM User 
        WHERE Username = :usernameWithSmi 
        LIMIT 1
    ];
    
    if (emailMatch.size() > 0) {
        emailMatches++;
        System.debug('  ✅ Email match found: ' + emailMatch[0].Username);
    } else if (fedMatch.size() > 0) {
        fedIdMatches++;
        System.debug('  ✅ FederationIdentifier match found: ' + fedMatch[0].Username);
    } else if (usernameMatch.size() > 0) {
        usernameMatches++;
        System.debug('  ✅ Username match found: ' + usernameMatch[0].Username);
    } else {
        noMatches++;
        System.debug('  ❌ No matches found');
    }
    System.debug('');
}

System.debug('=== SUMMARY ===');
System.debug('Email matches: ' + emailMatches);
System.debug('FederationIdentifier matches: ' + fedIdMatches);
System.debug('Username matches: ' + usernameMatches);
System.debug('No matches: ' + noMatches);
System.debug('Total analyzed: ' + failedContacts.size());

