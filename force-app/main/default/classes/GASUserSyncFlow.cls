public class GASUserSyncFlow {
    public class InputWrapper {
        @InvocableVariable(required=true)
        public List<UserSyncInput> users;
    }

    @InvocableMethod(label='Sync All Users to Google Workspace')
    public static void postToGoogle(List<InputWrapper> input) {
        if (input == null || input.isEmpty()) {
            System.debug('No input provided to GAS sync.');
            return;
        }

        List<UserSyncInput> users = input[0].users;
        String payload = JSON.serialize(users);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GoogleAppsScript');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('Google Workspace Sync Response: ' + res.getBody());
        } catch (Exception ex) {
            System.debug('Error during Google Apps Script sync: ' + ex.getMessage());
        }
    }
}