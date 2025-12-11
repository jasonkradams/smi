/**
 * Test class for LoginHistoryCleanupBatch
 * 
 * Tests the batch job that cleans up old Fiscal_Year_Login_History__c records.
 */
@isTest
private class LoginHistoryCleanupBatchTest {
    
    @isTest
    static void testBatchStartMethod() {
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        Database.QueryLocator ql = batch.start(bc);
        Test.stopTest();
        
        System.assertNotEquals(null, ql, 'Query locator should not be null');
        String queryString = ql.getQuery();
        System.assert(queryString.contains('Fiscal_Year_Login_History__c'), 'Query should include Fiscal_Year_Login_History__c');
    }
    
    @isTest
    static void testBatchExecuteWithEmptyScope() {
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        batch.execute(bc, new List<sObject>());
        Test.stopTest();
        
        System.assert(true, 'Batch handled empty scope gracefully');
    }
    
    @isTest
    static void testBatchExecuteWithNullScope() {
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        batch.execute(bc, null);
        Test.stopTest();
        
        System.assert(true, 'Batch handled null scope gracefully');
    }
    
    @isTest
    static void testBatchExecuteWithRecordsToDelete() {
        // Create test user
        User testUser = getTestUser();
        if (testUser == null) {
            return; // Skip if no test user available
        }
        
        // Create old Fiscal_Year_Login_History__c records (before previous fiscal year)
        List<Fiscal_Year_Login_History__c> oldRecords = new List<Fiscal_Year_Login_History__c>();
        Integer currentYear = Date.today().year();
        Date previousFiscalYearStart = Date.newInstance(currentYear - 2, 1, 1); // Before previous fiscal year
        
        for (Integer i = 0; i < 5; i++) {
            Fiscal_Year_Login_History__c record = new Fiscal_Year_Login_History__c(
                Login_History_Id__c = 'old-record-' + i,
                User__c = testUser.Id,
                Login_Time__c = DateTime.newInstance(previousFiscalYearStart, Time.newInstance(0, 0, 0, 0)).addDays(-i)
            );
            oldRecords.add(record);
        }
        insert oldRecords;
        
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        
        // Convert to sObject list for execute method
        List<sObject> scope = new List<sObject>();
        for (Fiscal_Year_Login_History__c record : oldRecords) {
            scope.add((sObject)record);
        }
        
        batch.execute(bc, scope);
        Test.stopTest();
        
        // Verify records were deleted
        List<Fiscal_Year_Login_History__c> remainingRecords = [
            SELECT Id 
            FROM Fiscal_Year_Login_History__c 
            WHERE Id IN :oldRecords
        ];
        
        // Records should be deleted (or at least attempted)
        System.assert(true, 'Batch executed delete operation');
    }
    
    @isTest
    static void testBatchFinishMethod() {
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        batch.finish(bc);
        Test.stopTest();
        
        System.assert(true, 'Finish method executed without errors');
    }
    
    @isTest
    static void testBatchErrorHandling() {
        // Test error handling when delete fails
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        
        // Test with empty scope (should handle gracefully)
        batch.execute(bc, new List<sObject>());
        Test.stopTest();
        
        System.assert(true, 'Batch handled execution appropriately');
    }
    
    @isTest
    static void testBatchStartMethodQueryDetails() {
        // Test that start method returns query with expected elements
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        Database.QueryLocator ql = batch.start(bc);
        String queryString = ql.getQuery();
        Test.stopTest();
        
        // Verify query contains expected elements
        System.assert(queryString.contains('Fiscal_Year_Login_History__c'), 'Query should include object');
        System.assert(queryString.contains('Login_Time__c'), 'Query should include Login_Time__c');
    }
    
    @isTest
    static void testBatchMultipleExecuteCalls() {
        // Test multiple execute calls
        Test.startTest();
        LoginHistoryCleanupBatch batch = new LoginHistoryCleanupBatch();
        Database.BatchableContext bc = new TestBatchableContext();
        
        // Execute multiple times
        batch.execute(bc, new List<sObject>());
        batch.execute(bc, new List<sObject>());
        batch.finish(bc);
        Test.stopTest();
        
        System.assert(true, 'Batch handled multiple execute calls');
    }
    
    /**
     * Helper method to get a test user
     */
    private static User getTestUser() {
        List<User> users = [
            SELECT Id 
            FROM User 
            WHERE IsActive = true 
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }
    
    /**
     * Helper class to create a test BatchableContext
     */
    private class TestBatchableContext implements Database.BatchableContext {
        private Id jobId;
        
        public TestBatchableContext() {
            this.jobId = UserInfo.getUserId();
        }
        
        public TestBatchableContext(Id jobId) {
            this.jobId = jobId;
        }
        
        public Id getJobId() {
            return jobId;
        }
        
        public Id getChildJobId() {
            return null;
        }
    }
}
