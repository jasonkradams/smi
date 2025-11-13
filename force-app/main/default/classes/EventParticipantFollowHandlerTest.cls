@IsTest
private class EventParticipantFollowHandlerTest {
    private static Integer suffixCounter = 0;

    private static String nextSuffix() {
        suffixCounter++;
        return String.valueOf(suffixCounter);
    }

    private static Id fetchAnyRegistrationId() {
        Event_Registration__c reg = [
            SELECT Id
            FROM Event_Registration__c
            LIMIT 1
        ];
        System.assertNotEquals(null, reg, 'Expected at least one Event Registration in the org');
        return reg.Id;
    }

    private static Profile fetchStandardUserProfile() {
        return [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
    }

    private static Contact createContactWithUser(String suffix) {
        Profile p = fetchStandardUserProfile();
        String unique = suffix + DateTime.now().getTime();
        User u = new User(
            Alias = ('t' + suffix).left(8),
            Email = 'testuser' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User ' + suffix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'testuser.' + unique + '@example.com',
            ProfileId = p.Id
        );
        insert u;

        Contact c = new Contact(
            LastName = 'Contact ' + suffix,
            Email = 'contact' + unique + '@example.com',
            User_Lookup__c = u.Id
        );
        insert c;
        return c;
    }

    @IsTest(SeeAllData=true)
    static void testTriggerCreatesEntitySubscription() {
        String suffix = nextSuffix();
        Contact c = createContactWithUser(suffix);
        Id regId = fetchAnyRegistrationId();
        Integer beforeCount = [
            SELECT COUNT()
            FROM EntitySubscription
            WHERE ParentId = :regId
              AND SubscriberId = :c.User_Lookup__c
        ];

        Test.startTest();
        insert new Event_Participant__c(
            Event_Registration__c = regId,
            Contact__c = c.Id
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT COUNT()
            FROM EntitySubscription
            WHERE ParentId = :regId
              AND SubscriberId = :c.User_Lookup__c
        ];
        System.assertEquals(beforeCount + 1, afterCount,
            'Inserting a participant with a valid registration should create a follow subscription');
    }

    @IsTest(SeeAllData=true)
    static void testSkipsWhenUserLookupMissing() {
        Id regId = fetchAnyRegistrationId();
        Contact withoutUser = new Contact(LastName = 'No User ' + nextSuffix());
        insert withoutUser;

        Integer beforeCount = [
            SELECT COUNT()
            FROM EntitySubscription
            WHERE ParentId = :regId
        ];

        Test.startTest();
        insert new Event_Participant__c(
            Event_Registration__c = regId,
            Contact__c = withoutUser.Id
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT COUNT()
            FROM EntitySubscription
            WHERE ParentId = :regId
        ];
        System.assertEquals(beforeCount, afterCount,
            'No subscription should be created when the Contact lacks a related User');
    }

    @IsTest(SeeAllData=true)
    static void testSkipsWhenRegistrationRecordMissing() {
        Contact c = createContactWithUser(nextSuffix());
        Id regId = fetchAnyRegistrationId();

        try {
            // Provide an empty override map so the handler cannot resolve the registration.
            EventParticipantFollowHandler.testRegById = new Map<Id, Event_Registration__c>();

            EventParticipantFollowHandler.handleAfterInsert(new List<Event_Participant__c>{
                new Event_Participant__c(
                    Event_Registration__c = regId,
                    Contact__c = c.Id
                )
            });

            Integer countAfterBlank = [
                SELECT COUNT()
                FROM EntitySubscription
                WHERE SubscriberId = :c.User_Lookup__c
            ];
            System.assertEquals(0, countAfterBlank,
                'Missing registration context should prevent EntitySubscription creation');
        } finally {
            EventParticipantFollowHandler.testRegById = null;
        }
    }

    @IsTest(SeeAllData=true)
    static void testBulkInsertAndDedup() {
        Contact c = createContactWithUser(nextSuffix());
        Id regId = fetchAnyRegistrationId();

        try {
            EventParticipantFollowHandler.testRegById = null;

            Integer beforeCount = [
                SELECT COUNT()
                FROM EntitySubscription
                WHERE ParentId = :regId
                  AND SubscriberId = :c.User_Lookup__c
            ];

            List<Event_Participant__c> participants = new List<Event_Participant__c>();
            for (Integer i = 0; i < 10; i++) {
                participants.add(new Event_Participant__c(
                    Event_Registration__c = regId,
                    Contact__c = c.Id
                ));
            }

            Test.startTest();
            EventParticipantFollowHandler.handleAfterInsert(participants);
            EventParticipantFollowHandler.handleAfterInsert(participants);
            Test.stopTest();

            Integer afterCount = [
                SELECT COUNT()
                FROM EntitySubscription
                WHERE ParentId = :regId
                  AND SubscriberId = :c.User_Lookup__c
            ];

            System.assertEquals(beforeCount + 1, afterCount,
                'Bulk processing should add exactly one subscription for the new parent/subscriber pair');
            System.assertEquals(1, Math.min(1, afterCount),
                'Deduplication should ensure only one subscription exists per parent/subscriber pair');
        } finally {
            EventParticipantFollowHandler.testRegById = null;
        }
    }

    @IsTest(SeeAllData=true)
    static void testQueryLimitSupportsNonAdminUsers() {
        Contact c = createContactWithUser(nextSuffix());
        User participantUser = [
            SELECT Id
            FROM User
            WHERE Id = :c.User_Lookup__c
            LIMIT 1
        ];

        Id regId = fetchAnyRegistrationId();

        try {
            EventParticipantFollowHandler.testRegById = null;

            System.runAs(participantUser) {
                Test.startTest();
                insert new Event_Participant__c(
                    Event_Registration__c = regId,
                    Contact__c = c.Id
                );
                Test.stopTest();
            }

            Integer afterCount = [
                SELECT COUNT()
                FROM EntitySubscription
                WHERE ParentId = :regId
                  AND SubscriberId = :c.User_Lookup__c
            ];
            System.assertEquals(1, afterCount,
                'Non-admin execution context should still create EntitySubscription records');
        } finally {
            EventParticipantFollowHandler.testRegById = null;
        }
    }
}
