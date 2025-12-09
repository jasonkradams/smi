/**
 * Test class for LicenseChangeLogQueueable
 */
@isTest
private class LicenseChangeLogQueueableTest {
    
    @isTest
    static void testInsertChangeLogs() {
        // Create a test user
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Profile.UserLicense.Name = 'Customer Community Plus' LIMIT 1];
        
        // Create change log records
        List<License_Change_Log__c> logs = new List<License_Change_Log__c>();
        License_Change_Log__c log1 = new License_Change_Log__c(
            User__c = testUser.Id,
            Old_License__c = 'Customer Community Plus Login',
            New_License__c = 'Customer Community Plus',
            Old_Profile__c = 'SM Community Plus Login',
            New_Profile__c = 'SM Community Plus Member',
            Login_Count__c = 25,
            Reason__c = 'High usage',
            Changed_At__c = DateTime.now(),
            Batch_Job_Id__c = '707VE00000TEST'
        );
        logs.add(log1);
        
        License_Change_Log__c log2 = new License_Change_Log__c(
            User__c = testUser.Id,
            Old_License__c = 'Customer Community Plus',
            New_License__c = 'Customer Community Plus Login',
            Old_Profile__c = 'SM Community Plus Member',
            New_Profile__c = 'SM Community Plus Login',
            Login_Count__c = 2,
            Reason__c = 'Low usage',
            Changed_At__c = DateTime.now(),
            Batch_Job_Id__c = '707VE00000TEST'
        );
        logs.add(log2);
        
        Test.startTest();
        LicenseChangeLogQueueable queueable = new LicenseChangeLogQueueable(logs);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify logs were inserted
        List<License_Change_Log__c> insertedLogs = [
            SELECT Id, User__c, Old_License__c, New_License__c, Reason__c
            FROM License_Change_Log__c
            WHERE Batch_Job_Id__c = '707VE00000TEST'
        ];
        
        System.assertEquals(2, insertedLogs.size(), 'Should have inserted 2 change log records');
    }
    
    @isTest
    static void testEmptyLogs() {
        Test.startTest();
        LicenseChangeLogQueueable queueable = new LicenseChangeLogQueueable(new List<License_Change_Log__c>());
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Should complete without error
        System.assert(true, 'Queueable should handle empty list gracefully');
    }
    
    @isTest
    static void testNullLogs() {
        Test.startTest();
        LicenseChangeLogQueueable queueable = new LicenseChangeLogQueueable(null);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Should complete without error
        System.assert(true, 'Queueable should handle null list gracefully');
    }
}

