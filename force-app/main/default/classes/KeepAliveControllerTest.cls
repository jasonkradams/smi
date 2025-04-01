@IsTest
private class KeepAliveControllerTest {

    @IsTest
    static void testPingMethodRunsSuccessfully() {
        Test.startTest();
        KeepAliveController.ping();
        Test.stopTest();
    }
}
