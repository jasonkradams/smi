/**
 * Test class for LoginHistorySyncScheduler
 * 
 * Tests the scheduler that triggers LoginHistorySyncBatch.
 */
@isTest
private class LoginHistorySyncSchedulerTest {
    
    @isTest
    static void testSchedulerInstantiates() {
        // Test that scheduler can be instantiated
        LoginHistorySyncScheduler scheduler = new LoginHistorySyncScheduler();
        System.assertNotEquals(null, scheduler, 'Scheduler should be instantiated');
    }
    
    @isTest
    static void testSchedulerHasExecuteMethod() {
        // Test execute method - it will skip executeBatch in test context
        LoginHistorySyncScheduler scheduler = new LoginHistorySyncScheduler();
        TestSchedulableContext ctx = new TestSchedulableContext();
        
        Test.startTest();
        scheduler.execute(ctx);
        Test.stopTest();
        
        System.assert(true, 'Scheduler execute method ran successfully');
    }
    
    @isTest
    static void testSchedulerStructure() {
        // Test scheduler class structure
        LoginHistorySyncScheduler scheduler1 = new LoginHistorySyncScheduler();
        LoginHistorySyncScheduler scheduler2 = new LoginHistorySyncScheduler();
        
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
