public class GASUserSyncFlow {
    public class InputWrapper {
        @InvocableVariable(required=true)
        public List<UserSyncInput> users;
    }

    @InvocableMethod(label='Sync All Users to Google Workspace')
    public static void postToGoogle(List<InputWrapper> input) {
        System.debug('=== GASUserSyncFlow: Starting user sync ===');
        System.debug('=== GASUserSyncFlow: Running user: ' + UserInfo.getUserName() + ' ===');

        if (input == null || input.isEmpty()) {
            System.debug('=== GASUserSyncFlow: No input provided to GAS sync. ===');
            return;
        }

        List<UserSyncInput> users = input[0].users;
        String payload;
        try {
            payload = JSON.serialize(users);
            System.debug('=== GASUserSyncFlow: Payload JSON ===\n' + payload);
        } catch (Exception e) {
            System.debug('=== GASUserSyncFlow: JSON serialization failed ===\n' + e.getMessage());
            return;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GoogleAppsScript');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);

        Http http = new Http();
        HttpResponse res;

        try {
            System.debug('=== GASUserSyncFlow: Sending HTTP request to GoogleAppsScript ===');
            res = http.send(req);
            System.debug('=== GASUserSyncFlow: Status Code === ' + res.getStatusCode());
            System.debug('=== GASUserSyncFlow: Response Body ===\n' + res.getBody());
        } catch (System.CalloutException calloutEx) {
            System.debug('=== GASUserSyncFlow: Callout Exception occurred ===');
            System.debug('=== Message === ' + calloutEx.getMessage());
            System.debug('=== Stack Trace ===\n' + calloutEx.getStackTraceString());
        } catch (Exception ex) {
            System.debug('=== GASUserSyncFlow: General Exception occurred ===');
            System.debug('=== Message === ' + ex.getMessage());
            System.debug('=== Stack Trace ===\n' + ex.getStackTraceString());
        }

        System.debug('=== GASUserSyncFlow: Completed ===');
    }
}
