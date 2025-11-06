@isTest
private class ContactUserSyncBatchTest {
    
    @testSetup
    static void makeData() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        
        String batchEmail = 'batchuser' + uniqueSuffix + '@example.com';
        String batchFedId = batchEmail.replace('@', '_') + '@spokanemountaineers.org';
        
        // Create test User with Email matching (most reliable match)
        User testUser = new User(
            Username = 'batchuser' + uniqueSuffix + '@example.com.smi',
            Email = batchEmail,
            FederationIdentifier = batchFedId,
            LastName = 'BatchUser',
            FirstName = 'Batch',
            Alias = 'buser' + uniqueSuffix.substring(0, 2),
            CommunityNickname = 'batchuser' + uniqueSuffix,
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create test Contacts
        List<Contact> contacts = new List<Contact>();
        
        // Contact with matching User email (will match via Email = Email)
        Contact matchingContact = new Contact(
            FirstName = 'Matching',
            LastName = 'Contact',
            Email = batchEmail
        );
        contacts.add(matchingContact);
        
        // Contact with no matching User
        Contact unmatchedContact = new Contact(
            FirstName = 'Unmatched',
            LastName = 'Contact',
            Email = 'unmatched' + uniqueSuffix + '@example.com'
        );
        contacts.add(unmatchedContact);
        
        // Contact without email
        Contact noEmailContact = new Contact(
            FirstName = 'NoEmail',
            LastName = 'Contact'
        );
        contacts.add(noEmailContact);
        
        insert contacts;
    }
    
    @isTest
    static void testBatchSync() {
        Test.startTest();
        
        // Execute the batch
        ContactUserSyncBatch batch = new ContactUserSyncBatch();
        Database.executeBatch(batch, 200);
        
        Test.stopTest();
        
        // Verify results
        List<Contact> contacts = [
            SELECT Id, Email, User_Lookup__c 
            FROM Contact 
            ORDER BY LastName
        ];
        
        // Find matching contact by email
        Contact matchingContact = null;
        Contact unmatchedContact = null;
        Contact noEmailContact = null;
        
        for (Contact c : contacts) {
            if (c.Email != null && c.Email.contains('batchuser')) {
                matchingContact = c;
            } else if (c.Email != null && c.Email.contains('unmatched')) {
                unmatchedContact = c;
            } else if (c.Email == null) {
                noEmailContact = c;
            }
        }
        
        // Matching contact should have User lookup
        System.assertNotEquals(null, matchingContact, 'Matching contact should exist');
        System.assertNotEquals(null, matchingContact.User_Lookup__c, 'Matching contact should have User lookup');
        
        // Unmatched contact should not have User lookup
        System.assertNotEquals(null, unmatchedContact, 'Unmatched contact should exist');
        System.assertEquals(null, unmatchedContact.User_Lookup__c, 'Unmatched contact should not have User lookup');
        
        // No email contact should not have User lookup
        System.assertNotEquals(null, noEmailContact, 'No email contact should exist');
        System.assertEquals(null, noEmailContact.Email, 'No email contact should have null Email');
        System.assertEquals(null, noEmailContact.User_Lookup__c, 'No email contact should not have User lookup');
    }
    
    @isTest
    static void testBatchSync_AlreadyLinked() {
        // Get test data - find contact with email containing 'batchuser'
        Contact matchingContact = [
            SELECT Id, Email 
            FROM Contact 
            WHERE Email != null 
            AND Email LIKE '%batchuser%@example.com'
            LIMIT 1
        ];
        User testUser = [
            SELECT Id 
            FROM User 
            WHERE Email = :matchingContact.Email
            LIMIT 1
        ];
        
        // Pre-link the Contact
        matchingContact.User_Lookup__c = testUser.Id;
        update matchingContact;
        
        Test.startTest();
        
        // Execute the batch
        ContactUserSyncBatch batch = new ContactUserSyncBatch();
        Database.executeBatch(batch, 200);
        
        Test.stopTest();
        
        // Verify the Contact still has the same User lookup
        Contact updatedContact = [SELECT User_Lookup__c FROM Contact WHERE Id = :matchingContact.Id LIMIT 1];
        System.assertEquals(testUser.Id, updatedContact.User_Lookup__c);
    }
}
