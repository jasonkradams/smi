@isTest
private class EventParticipantRedirectHelperTest {
    // Cache ProfileId to avoid querying it multiple times
    private static Id standardUserProfileId;
    
    private static Id getStandardUserProfileId() {
        if (standardUserProfileId == null) {
            standardUserProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        }
        return standardUserProfileId;
    }

    @testSetup
    static void makeData() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        // Create test User
        User testUser = new User(
            Username = 'testuser' + uniqueSuffix + '@example.com',
            Email = 'testuser' + uniqueSuffix + '@example.com',
            LastName = 'TestUser',
            FirstName = 'Test',
            Alias = 'testus' + uniqueSuffix.substring(0, 2),
            CommunityNickname = 'testuser' + uniqueSuffix,
            ProfileId = getStandardUserProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testuser' + uniqueSuffix + '@example.com'
        );
        insert testContact;

        // Link Contact to User
        testContact.User_Lookup__c = testUser.Id;
        update testContact;

        // Create test Event
        Event testEvent = new Event(
            Subject = 'Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert testEvent;

        // Create EventRelation
        EventRelation eventRelation = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testContact.Id,
            Status = 'Accepted',
            Response = 'Accepted'
        );
        insert eventRelation;
    }

    @isTest
    static void testGetUserRedirectUrl_Success() {
        Contact testContact = [SELECT Id, User_Lookup__c FROM Contact LIMIT 1];
        EventRelation eventRelation = [SELECT Id FROM EventRelation WHERE RelationId = :testContact.Id LIMIT 1];
        User testUser = [SELECT Id FROM User LIMIT 1];

        Test.startTest();
        String redirectUrl = EventParticipantRedirectHelper.getUserRedirectUrl(eventRelation.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, redirectUrl);
        System.assertEquals('/s/profile/' + testContact.User_Lookup__c, redirectUrl);
    }

    @isTest
    static void testGetUserRedirectUrl_NoUser() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        EventRelation eventRelation = [SELECT Id FROM EventRelation WHERE RelationId = :testContact.Id LIMIT 1];
        
        testContact.User_Lookup__c = null;
        update testContact;
        
        Test.startTest();
        String redirectUrl = EventParticipantRedirectHelper.getUserRedirectUrl(eventRelation.Id);
        Test.stopTest();
        
        System.assertEquals(null, redirectUrl);
    }

    @isTest
    static void testGetUserRedirectUrl_InvalidId() {
        Test.startTest();
        String redirectUrl = EventParticipantRedirectHelper.getUserRedirectUrl('invalidId');
        Test.stopTest();
        
        System.assertEquals(null, redirectUrl);
    }

    @isTest
    static void testGetUserRedirectUrl_LeadRelation() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        Lead testLead = new Lead(
            FirstName = 'URL',
            LastName = 'Lead' + uniqueSuffix,
            Company = 'Test Co',
            Email = 'urllead' + uniqueSuffix + '@example.com'
        );
        insert testLead;

        Event testEvent = new Event(
            Subject = 'URL Lead Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert testEvent;

        EventRelation er = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testLead.Id,
            Status = 'Accepted',
            Response = 'Accepted'
        );
        insert er;

        Test.startTest();
        String redirectUrl = EventParticipantRedirectHelper.getUserRedirectUrl(er.Id);
        Test.stopTest();

        System.assertEquals(null, redirectUrl);
    }

    @isTest
    static void testGetEventParticipants_EventRelation() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        User testUser = [SELECT Id FROM User LIMIT 1];
        Event testEvent = [SELECT Id FROM Event LIMIT 1];
        
        testContact.User_Lookup__c = testUser.Id;
        update testContact;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants(testEvent.Id);
        Test.stopTest();
        
        System.assertEquals(1, participants.size());
        EventParticipantRedirectHelper.ParticipantWrapper participant = participants[0];
        System.assertEquals(testContact.Id, participant.contactId);
        System.assertEquals('Test Contact', participant.contactName);
        System.assertEquals(testUser.Id, participant.userId);
        System.assertEquals(true, participant.hasUser);
        System.assertEquals('Accepted', participant.status);
        System.assertEquals('Accepted', participant.response);
    }

    @isTest
    static void testGetEventParticipants_WhoId() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        User testUser = new User(
            Username = 'whocontact' + uniqueSuffix + '@example.com',
            Email = 'whocontact' + uniqueSuffix + '@example.com',
            LastName = 'WhoUser',
            FirstName = 'Test',
            Alias = 'whous' + uniqueSuffix.substring(0, 2),
            CommunityNickname = 'whocontact' + uniqueSuffix,
            ProfileId = getStandardUserProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Contact testContact = new Contact(
            FirstName = 'Who',
            LastName = 'Contact',
            Email = 'whocontact' + uniqueSuffix + '@example.com',
            User_Lookup__c = testUser.Id
        );
        insert testContact;
        
        Event testEvent = new Event(
            Subject = 'WhoId Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2),
            WhoId = testContact.Id
        );
        insert testEvent;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants(testEvent.Id);
        Test.stopTest();
        
        System.assertEquals(1, participants.size());
        EventParticipantRedirectHelper.ParticipantWrapper participant = participants[0];
        System.assertEquals(testContact.Id, participant.contactId);
        System.assertEquals('Who Contact', participant.contactName);
        System.assertEquals(testUser.Id, participant.userId);
        System.assertEquals(true, participant.hasUser);
    }

    

    @isTest
    static void testGetEventParticipants_LeadRelation() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead' + uniqueSuffix,
            Company = 'Test Company',
            Email = 'testlead' + uniqueSuffix + '@example.com'
        );
        insert testLead;
        
        Event testEvent = new Event(
            Subject = 'Lead Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert testEvent;
        
        EventRelation eventRelation = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testLead.Id,
            Status = 'Accepted',
            Response = 'Accepted'
        );
        insert eventRelation;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants(testEvent.Id);
        Test.stopTest();
        
        System.assertEquals(1, participants.size());
        EventParticipantRedirectHelper.ParticipantWrapper participant = participants[0];
        System.assertEquals(testLead.Id, participant.contactId);
        System.assertEquals(false, participant.hasUser);
    }

    @isTest
    static void testSyncContactToUser_Success() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        String contactEmail = 'syncuser' + uniqueSuffix + '@example.com';
        // Transform Email to FederationIdentifier format: replace @ with _, append @spokanemountaineers.org
        String federationIdentifier = contactEmail.replace('@', '_') + '@spokanemountaineers.org';
        
        // Create User with FederationIdentifier matching transformed Contact.Email
        User testUser = new User(
            Username = 'syncuser' + uniqueSuffix + '@example.com.smi',
            Email = contactEmail,
            FederationIdentifier = federationIdentifier,  // Match transformed Contact.Email
            LastName = 'SyncUser',
            FirstName = 'Test',
            Alias = 'syncus' + uniqueSuffix.substring(0, 2),
            CommunityNickname = 'syncuser' + uniqueSuffix,
            ProfileId = getStandardUserProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create Contact with Email
        Contact testContact = new Contact(
            FirstName = 'Sync',
            LastName = 'Contact',
            Email = contactEmail
        );
        insert testContact;
        
        Test.startTest();
        Boolean result = EventParticipantRedirectHelper.syncContactToUser(testContact.Id);
        Test.stopTest();
        
        System.assertEquals(true, result);
        
        Contact updatedContact = [SELECT User_Lookup__c FROM Contact WHERE Id = :testContact.Id LIMIT 1];
        System.assertEquals(testUser.Id, updatedContact.User_Lookup__c);
    }

    @isTest
    static void testSyncContactToUser_AlreadySynced() {
        Contact testContact = [SELECT Id, User_Lookup__c FROM Contact LIMIT 1];
        User testUser = [SELECT Id FROM User LIMIT 1];
        
        testContact.User_Lookup__c = testUser.Id;
        update testContact;
        
        Test.startTest();
        Boolean result = EventParticipantRedirectHelper.syncContactToUser(testContact.Id);
        Test.stopTest();
        
        System.assertEquals(true, result);
    }

    @isTest
    static void testSyncContactToUser_NoMatch() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        Contact testContact = new Contact(
            FirstName = 'NoMatch',
            LastName = 'Contact',
            Email = 'nomatch' + uniqueSuffix + '@example.com'
        );
        insert testContact;
        
        Test.startTest();
        Boolean result = EventParticipantRedirectHelper.syncContactToUser(testContact.Id);
        Test.stopTest();
        
        System.assertEquals(false, result);
    }

    @isTest
    static void testSyncContactToUser_InvalidId() {
        Test.startTest();
        Boolean result = EventParticipantRedirectHelper.syncContactToUser('invalidId');
        Test.stopTest();
        
        System.assertEquals(false, result);
    }

    @isTest
    static void testBulkSyncContactsToUsers_MixedResults() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        Id profileId = getStandardUserProfileId();
        
        // Create Users with FederationIdentifiers matching transformed Contact.Email pattern
        String bulkEmail = 'bulkuser' + uniqueSuffix + '@example.com';
        // Transform Email to FederationIdentifier format: replace @ with _, append @spokanemountaineers.org
        String bulkFederationId = bulkEmail.replace('@', '_') + '@spokanemountaineers.org';
        
        String matchEmail = 'matchuser' + uniqueSuffix + '@example.com';
        String matchFederationId = matchEmail.replace('@', '_') + '@spokanemountaineers.org';
        
        List<User> usersToInsert = new List<User>{
            new User(
                Username = 'bulkuser' + uniqueSuffix + '@example.com.smi',
                Email = bulkEmail,
                FederationIdentifier = bulkFederationId,  // Match transformed Contact.Email
                LastName = 'BulkUser',
                FirstName = 'Test',
                Alias = 'bulkus' + uniqueSuffix.substring(0, 2),
                CommunityNickname = 'bulkuser' + uniqueSuffix,
                ProfileId = profileId,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            ),
            new User(
                Username = 'matchuser' + uniqueSuffix + '@example.com.smi',
                Email = matchEmail,
                FederationIdentifier = matchFederationId,  // Match transformed Contact.Email
                LastName = 'MatchUser',
                FirstName = 'Test',
                Alias = 'match' + uniqueSuffix.substring(0,2),
                CommunityNickname = 'matchuser' + uniqueSuffix,
                ProfileId = profileId,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            )
        };
        insert usersToInsert;
        
        User testUser = usersToInsert[0];
        
        // Create all contacts - Username_Formula__c will be calculated from Email
        List<Contact> contactsToInsert = new List<Contact>{
            new Contact(
                FirstName = 'Matching',
                LastName = 'Contact',
                Email = bulkEmail  // Username_Formula__c will be: bulkEmail.replace('@', '_') + '@spokanemountaineers.org'
            ),
            new Contact(
                FirstName = 'Non',
                LastName = 'Matching',
                Email = 'nomatch' + uniqueSuffix + '@example.com'  // No matching User
            ),
            new Contact(
                FirstName = 'Already',
                LastName = 'Synced',
                Email = bulkEmail
            ),
            new Contact(
                FirstName = 'No',
                LastName = 'Email'  // No email, so no Username_Formula__c
            ),
            new Contact(
                FirstName = 'Match',
                LastName = 'User',
                Email = matchEmail  // Username_Formula__c will be: matchEmail.replace('@', '_') + '@spokanemountaineers.org'
            )
        };
        insert contactsToInsert;
        
        // Username_Formula__c is a formula field and will auto-calculate from Email
        // Re-query to get actual Username_Formula__c values (formula fields)
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([
            SELECT Id, Username_Formula__c 
            FROM Contact 
            WHERE Id IN :contactsToInsert
        ]);
        
        Contact matchingContact = contactsMap.get(contactsToInsert[0].Id);
        Contact nonMatchingContact = contactsMap.get(contactsToInsert[1].Id);
        Contact alreadySynced = contactsMap.get(contactsToInsert[2].Id);
        Contact noEmail = contactsMap.get(contactsToInsert[3].Id);
        Contact matchContact = contactsMap.get(contactsToInsert[4].Id);
        
        // Update already synced contact
        alreadySynced = contactsToInsert[2];
        alreadySynced.User_Lookup__c = testUser.Id;
        update alreadySynced;
        
        Test.startTest();
        List<String> contactIds = new List<String>{
            matchingContact.Id,
            nonMatchingContact.Id,
            alreadySynced.Id,
            noEmail.Id,
            matchContact.Id
        };
        
        List<EventParticipantRedirectHelper.SyncResult> results = 
            EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);
        Test.stopTest();
        
        System.assertEquals(5, results.size());
        System.assertEquals(true, results[0].success);  // Username_Formula__c match
        System.assertEquals(false, results[1].success); // no match
        System.assertEquals(true, results[2].success);  // already synced
        System.assertEquals(false, results[3].success); // no Username_Formula__c
        System.assertEquals(true, results[4].success);  // Username_Formula__c match
    }

    @isTest
    static void testSyncContactsToUsers_Batch() {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        String contactEmail = 'batchuser' + uniqueSuffix + '@example.com';
        String usernameFormula = contactEmail + '.spokane';
        
        User testUser = new User(
            Username = usernameFormula,  // Match Contact.Username_Formula__c
            Email = contactEmail,
            LastName = 'BatchUser',
            FirstName = 'Test',
            Alias = 'btchus' + uniqueSuffix.substring(0, 2),
            CommunityNickname = 'batchuser' + uniqueSuffix,
            ProfileId = getStandardUserProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Contact testContact = new Contact(
            FirstName = 'Batch',
            LastName = 'Contact',
            Email = contactEmail
        );
        insert testContact;
        
        // Username_Formula__c is a formula field and will auto-calculate from Email
        // User.Username already matches the expected Username_Formula__c pattern
        
        Test.startTest();
        List<EventParticipantRedirectHelper.SyncRequest> requests = new List<EventParticipantRedirectHelper.SyncRequest>();
        
        EventParticipantRedirectHelper.SyncRequest request = new EventParticipantRedirectHelper.SyncRequest();
        request.contactId = testContact.Id;
        requests.add(request);
        
        List<EventParticipantRedirectHelper.SyncResult> results = 
            EventParticipantRedirectHelper.syncContactsToUsers(requests);
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
    }

    @isTest
    static void testGetEventParticipants_EventRegistration_SimulatedFallback() {
        // Simulate a found Event_Registration__c but with no Event lookup field path exercised
        EventParticipantRedirectHelper.TEST_SIMULATE_EVENT_REG = true;
        EventParticipantRedirectHelper.TEST_RELATED_EVENT_ID = null;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants('a122G0000000000AAA');
        Test.stopTest();
        
        // If no Event lookup field is discovered, fallback returns a single wrapper
        System.assertEquals(1, participants.size());
        System.assertEquals('Event Registration', participants[0].response);
        System.assertEquals(false, participants[0].hasUser);
        
        // reset flags
        EventParticipantRedirectHelper.TEST_SIMULATE_EVENT_REG = false;
        EventParticipantRedirectHelper.TEST_RELATED_EVENT_ID = null;
    }

    @isTest
    static void testGetEventParticipants_EventRegistration_SimulatedWithEventId() {
        // Simulate full dynamic query path with a related Event Id
        Event evt = new Event(Subject='SimEvt', StartDateTime=System.now(), EndDateTime=System.now().addHours(1));
        insert evt;
        
        EventParticipantRedirectHelper.TEST_SIMULATE_EVENT_REG = true;
        EventParticipantRedirectHelper.TEST_RELATED_EVENT_ID = evt.Id;
        EventParticipantRedirectHelper.TEST_FAKE_REGS = new List<Event_Registration__c>{
            new Event_Registration__c(Name='Fake 1', Status__c='Registered')
        };
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants('a122G0000000000AAA');
        Test.stopTest();
        
        // One fake registration processed
        System.assertEquals(1, participants.size());
        System.assertEquals(false, participants[0].hasUser);
        System.assertEquals('Event Registration', participants[0].response);
        
        // reset flags
        EventParticipantRedirectHelper.TEST_SIMULATE_EVENT_REG = false;
        EventParticipantRedirectHelper.TEST_RELATED_EVENT_ID = null;
        EventParticipantRedirectHelper.TEST_FAKE_REGS = null;
    }

    @isTest
    static void testGetEventParticipants_MalformedId_NoResults() {
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants('abc');
        Test.stopTest();
        System.assertEquals(0, participants.size());
    }

    @isTest
    static void testGetEventParticipants_WhoId_LeadException() {
        // Test WhoId exception handling when WhoId is a Lead (lines 146-149)
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        Lead testLead = new Lead(
            FirstName = 'WhoIdLead',
            LastName = 'Exception' + uniqueSuffix,
            Company = 'Test Company',
            Email = 'whoidlead' + uniqueSuffix + '@example.com'
        );
        insert testLead;
        
        Event testEvent = new Event(
            Subject = 'WhoId Lead Exception Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2),
            WhoId = testLead.Id
        );
        insert testEvent;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants(testEvent.Id);
        Test.stopTest();
        
        System.assertEquals(0, participants.size());
    }

    @isTest
    static void testGetEventParticipants_EventRelation_MultipleRelations() {
        // Test multiple EventRelations processing (lines 137-138)
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).substring(8);
        
        Contact testContact1 = new Contact(
            FirstName = 'Multi1',
            LastName = 'Contact' + uniqueSuffix,
            Email = 'multi1contact' + uniqueSuffix + '@example.com'
        );
        insert testContact1;
        
        Contact testContact2 = new Contact(
            FirstName = 'Multi2',
            LastName = 'Contact' + uniqueSuffix,
            Email = 'multi2contact' + uniqueSuffix + '@example.com'
        );
        insert testContact2;
        
        Event testEvent = new Event(
            Subject = 'Multi Relations Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert testEvent;
        
        EventRelation relation1 = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testContact1.Id,
            Status = 'Accepted',
            Response = 'Accepted'
        );
        insert relation1;
        
        EventRelation relation2 = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testContact2.Id,
            Status = 'Declined',
            Response = 'Declined'
        );
        insert relation2;
        
        Test.startTest();
        List<EventParticipantRedirectHelper.ParticipantWrapper> participants = 
            EventParticipantRedirectHelper.getEventParticipants(testEvent.Id);
        Test.stopTest();
        
        System.assertEquals(2, participants.size());
    }
}
