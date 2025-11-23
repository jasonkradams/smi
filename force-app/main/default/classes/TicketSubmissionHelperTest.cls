@isTest
private class TicketSubmissionHelperTest {
    
    @TestSetup
    static void setupTestData() {
        // Create a Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Member',
            Email = 'testmember@example.com'
        );
        insert testContact;
        
        // Create a User with Contact
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Member',
            Email = 'testmember@example.com',
            Username = 'testmember@example.com.test',
            Alias = 'tmember',
            ProfileId = communityProfile.Id,
            ContactId = testContact.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create Case Record Types
        List<RecordType> recordTypes = [
            SELECT Id, DeveloperName 
            FROM RecordType 
            WHERE SObjectType = 'Case' 
            AND DeveloperName IN ('Technical_Bug', 'Feature_Request', 'Account_Access', 'General_Feedback')
        ];
        
        // Create Queues
        Group techQueue = new Group(
            Name = 'Technical Support Queue',
            Type = 'Queue'
        );
        insert techQueue;
        
        QueueSObject techQueueSObject = new QueueSObject(
            QueueId = techQueue.Id,
            SObjectType = 'Case'
        );
        insert techQueueSObject;
        
        Group feedbackQueue = new Group(
            Name = 'Product Feedback Queue',
            Type = 'Queue'
        );
        insert feedbackQueue;
        
        QueueSObject feedbackQueueSObject = new QueueSObject(
            QueueId = feedbackQueue.Id,
            SObjectType = 'Case'
        );
        insert feedbackQueueSObject;
    }
    
    @isTest
    static void testGetContactForUser() {
        // Get test user
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Id contactId = TicketSubmissionHelper.getContactForUser();
            Test.stopTest();
            
            System.assertNotEquals(null, contactId, 'Contact ID should not be null');
            
            Contact contact = [SELECT Id, Email FROM Contact WHERE Id = :contactId LIMIT 1];
            System.assertEquals('testmember@example.com', contact.Email, 'Contact email should match');
        }
    }
    
    @isTest
    static void testCreateCase() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        RecordType techBugType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Technical_Bug' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Case newCase = TicketSubmissionHelper.createCase(
                'Test Bug',
                'This is a test bug description that is long enough',
                techBugType.Id,
                'High'
            );
            Test.stopTest();
            
            System.assertNotEquals(null, newCase.Id, 'Case should be created');
            System.assertNotEquals(null, newCase.CaseNumber, 'Case Number should be generated');
            System.assertEquals('Test Bug', newCase.Subject, 'Subject should match');
            System.assertEquals('High', newCase.Priority, 'Priority should match');
            
            Case createdCase = [
                SELECT Id, Subject, Description, ContactId, Origin, RecordTypeId
                FROM Case
                WHERE Id = :newCase.Id
                LIMIT 1
            ];
            
            System.assertEquals('Web', createdCase.Origin, 'Origin should be Web');
            System.assertEquals(techBugType.Id, createdCase.RecordTypeId, 'Record Type should match');
        }
    }
    
    @isTest
    static void testCreateCaseValidationErrors() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        RecordType techBugType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Technical_Bug' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Test missing subject
            try {
                TicketSubmissionHelper.createCase(null, 'Description', techBugType.Id, null);
                System.assert(false, 'Should have thrown exception for missing subject');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Subject is required'), 'Error message should mention subject');
            }
            
            // Test short description
            try {
                TicketSubmissionHelper.createCase('Subject', 'Short', techBugType.Id, null);
                System.assert(false, 'Should have thrown exception for short description');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Description'), 'Error message should mention description');
            }
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testAddComment() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testmember@example.com' LIMIT 1];
        RecordType techBugType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Technical_Bug' LIMIT 1];
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Case',
            Description = 'Test Description',
            ContactId = testContact.Id,
            RecordTypeId = techBugType.Id,
            Status = 'New'
        );
        insert testCase;
        
        System.runAs(testUser) {
            Test.startTest();
            CaseComment comment = TicketSubmissionHelper.addComment(
                testCase.Id,
                'This is a test comment'
            );
            Test.stopTest();
            
            System.assertNotEquals(null, comment.Id, 'Comment should be created');
            System.assertEquals(true, comment.IsPublished, 'Comment should be published');
            
            CaseComment createdComment = [
                SELECT Id, CommentBody, IsPublished, ParentId
                FROM CaseComment
                WHERE Id = :comment.Id
                LIMIT 1
            ];
            
            System.assertEquals('This is a test comment', createdComment.CommentBody, 'Comment body should match');
        }
    }
    
    @isTest
    static void testAddCommentToClosedCase() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testmember@example.com' LIMIT 1];
        RecordType techBugType = [SELECT Id FROM RecordType WHERE DeveloperName = 'Technical_Bug' LIMIT 1];
        
        // Create a closed Case
        Case testCase = new Case(
            Subject = 'Test Case',
            Description = 'Test Description',
            ContactId = testContact.Id,
            RecordTypeId = techBugType.Id,
            Status = 'Closed'
        );
        insert testCase;
        
        System.runAs(testUser) {
            Test.startTest();
            try {
                TicketSubmissionHelper.addComment(testCase.Id, 'This is a test comment');
                System.assert(false, 'Should have thrown exception for closed case');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('closed'), 'Error message should mention closed');
            }
            Test.stopTest();
        }
    }
}

