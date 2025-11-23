@isTest
private class TicketQueryHelperTest {
    
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
        
        // Create Record Types
        List<RecordType> recordTypes = [
            SELECT Id, DeveloperName 
            FROM RecordType 
            WHERE SObjectType = 'Case' 
            AND DeveloperName IN ('Technical_Bug', 'Feature_Request')
        ];
        
        // Create test Cases
        List<Case> testCases = new List<Case>();
        
        for (Integer i = 0; i < 3; i++) {
            RecordType rt = recordTypes[i < 2 ? 0 : 1];
            Case testCase = new Case(
                Subject = 'Test Case ' + i,
                Description = 'Test Description ' + i,
                ContactId = testContact.Id,
                RecordTypeId = rt.Id,
                Status = i == 0 ? 'New' : (i == 1 ? 'Closed' : 'In Progress')
            );
            testCases.add(testCase);
        }
        insert testCases;
        
        // Create test comments
        List<CaseComment> comments = new List<CaseComment>();
        for (Case c : testCases) {
            CaseComment comment = new CaseComment(
                ParentId = c.Id,
                CommentBody = 'Test comment for ' + c.Subject,
                IsPublished = true
            );
            comments.add(comment);
        }
        insert comments;
    }
    
    @isTest
    static void testGetMyTickets() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            List<Case> tickets = TicketQueryHelper.getMyTickets();
            Test.stopTest();
            
            System.assertEquals(3, tickets.size(), 'Should return 3 tickets');
            System.assertEquals('Test Case 0', tickets[0].Subject, 'Should be ordered by CreatedDate DESC');
        }
    }
    
    @isTest
    static void testGetTicketDetails() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case 0' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Case ticketDetails = TicketQueryHelper.getTicketDetails(testCase.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, ticketDetails, 'Ticket details should be returned');
            System.assertEquals('Test Case 0', ticketDetails.Subject, 'Subject should match');
            System.assertNotEquals(null, ticketDetails.CaseNumber, 'Case Number should be populated');
        }
    }
    
    @isTest
    static void testGetTicketDetailsNotFound() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        
        // Create another Contact and Case that doesn't belong to test user
        Contact otherContact = new Contact(
            FirstName = 'Other',
            LastName = 'Member',
            Email = 'other@example.com'
        );
        insert otherContact;
        
        Case otherCase = new Case(
            Subject = 'Other Case',
            Description = 'Other Description',
            ContactId = otherContact.Id,
            Status = 'New'
        );
        insert otherCase;
        
        System.runAs(testUser) {
            Test.startTest();
            try {
                TicketQueryHelper.getTicketDetails(otherCase.Id);
                System.assert(false, 'Should have thrown exception for unauthorized access');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('not found') || e.getMessage().contains('permission'), 
                    'Error message should mention permission or not found');
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetTicketComments() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case 0' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            List<CaseComment> comments = TicketQueryHelper.getTicketComments(testCase.Id);
            Test.stopTest();
            
            System.assertEquals(1, comments.size(), 'Should return 1 comment');
            System.assertEquals(true, comments[0].IsPublished, 'Comment should be published');
        }
    }
    
    @isTest
    static void testGetMyTicketsByStatus() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testmember@example.com.test' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            List<Case> openTickets = TicketQueryHelper.getMyTicketsByStatus('Open');
            List<Case> closedTickets = TicketQueryHelper.getMyTicketsByStatus('Closed');
            List<Case> allTickets = TicketQueryHelper.getMyTicketsByStatus('All');
            
            Test.stopTest();
            
            System.assertEquals(2, openTickets.size(), 'Should return 2 open tickets');
            System.assertEquals(1, closedTickets.size(), 'Should return 1 closed ticket');
            System.assertEquals(3, allTickets.size(), 'Should return all 3 tickets');
        }
    }
}

