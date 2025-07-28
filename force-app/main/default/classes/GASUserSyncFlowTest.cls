@isTest
private class GASUserSyncFlowTest {

    @isTest
    static void testPostToGoogle_withWrapperMock() {
        // Create test user input
        UserSyncInput user = new UserSyncInput();
        user.email = 'sync.test@spokanemountaineers.org';
        user.first_name = 'Sync';
        user.last_name = 'Test';
        user.federation_id = 'sync.test@spokanemountaineers.org';

        System.debug('Running user: ' + UserInfo.getUserName());
        System.debug('UserId: ' + UserInfo.getUserId());
        System.debug('ProfileId: ' + [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()].ProfileId);

        // Wrap in InputWrapper
        GASUserSyncFlow.InputWrapper wrapper = new GASUserSyncFlow.InputWrapper();
        wrapper.users = new List<UserSyncInput>{ user };

        // Register mock response
        Test.setMock(HttpCalloutMock.class, new MockGASResponse());

        Test.startTest();
        GASUserSyncFlow.postToGoogle(new List<GASUserSyncFlow.InputWrapper>{ wrapper });
        Test.stopTest();
    }

    private class MockGASResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }
}