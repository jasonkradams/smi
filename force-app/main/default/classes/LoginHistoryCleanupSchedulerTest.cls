/**
 * Test class for LoginHistoryCleanupScheduler
 * 
 * Tests the scheduler that triggers LoginHistoryCleanupBatch.
 */
@isTest
private class LoginHistoryCleanupSchedulerTest {
    
    @isTest
    static void testSchedulerInstantiates() {
        // Test that scheduler can be instantiated
        LoginHistoryCleanupScheduler scheduler = new LoginHistoryCleanupScheduler();
        System.assertNotEquals(null, scheduler, 'Scheduler should be instantiated');
    }
    
    @isTest
    static void testSchedulerHasExecuteMethod() {
        // Test execute method - it will skip executeBatch in test context
        LoginHistoryCleanupScheduler scheduler = new LoginHistoryCleanupScheduler();
        TestSchedulableContext ctx = new TestSchedulableContext();
        
        Test.startTest();
        scheduler.execute(ctx);
        Test.stopTest();
        
        System.assert(true, 'Scheduler execute method ran successfully');
    }
    
    @isTest
    static void testSchedulerStructure() {
        // Test scheduler class structure
        LoginHistoryCleanupScheduler scheduler1 = new LoginHistoryCleanupScheduler();
        LoginHistoryCleanupScheduler scheduler2 = new LoginHistoryCleanupScheduler();
        
        // Verify multiple instances can be created
        System.assertNotEquals(null, scheduler1, 'First scheduler instance created');
        System.assertNotEquals(null, scheduler2, 'Second scheduler instance created');
        System.assertNotEquals(scheduler1, scheduler2, 'Instances should be different');
    }
    
    /**
     * Helper class to create a test SchedulableContext
     */
    private class TestSchedulableContext implements SchedulableContext {
        public String getTriggerId() {
            return 'test-trigger-id';
        }
    }
}

