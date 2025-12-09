/**
 * Utility class to create LoginHistory records for testing
 * 
 * Since LoginHistory is read-only, this class uses HTTP callouts
 * to authenticate as users, which automatically creates LoginHistory records.
 * 
 * Usage:
 *   LoginHistoryTestDataCreator creator = new LoginHistoryTestDataCreator();
 *   creator.createLoginsForUser(userId, 25);
 *   System.enqueueJob(creator);
 */
public class LoginHistoryTestDataCreator implements Queueable, Database.AllowsCallouts {
    
    private Id userId;
    private Integer loginCount;
    private String username;
    private String password;
    private String securityToken;
    private String instanceUrl;
    private Integer currentLogin = 0;
    
    /**
     * Constructor for creating logins for a specific user
     */
    public LoginHistoryTestDataCreator(Id userId, Integer loginCount) {
        this.userId = userId;
        this.loginCount = loginCount;
        
        // Get user info
        User u = [SELECT Username FROM User WHERE Id = :userId LIMIT 1];
        this.username = u.Username;
        
        // Get org info
        Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
        this.instanceUrl = 'https://' + org.InstanceName.toLowerCase() + '.salesforce.com';
    }
    
    /**
     * Alternative constructor with explicit credentials
     */
    public LoginHistoryTestDataCreator(String username, String password, String securityToken, Integer loginCount) {
        this.username = username;
        this.password = password;
        this.securityToken = securityToken;
        this.loginCount = loginCount;
        Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
        this.instanceUrl = 'https://' + org.InstanceName.toLowerCase() + '.salesforce.com';
    }
    
    public void execute(QueueableContext context) {
        if (currentLogin >= loginCount) {
            System.debug('Completed creating ' + loginCount + ' logins for user: ' + username);
            return;
        }
        
        // Make HTTP callout to authenticate (this creates a LoginHistory record)
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(instanceUrl + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Note: This requires a Connected App with OAuth settings
            // For testing, you may need to use a different approach
            String body = 'grant_type=password' +
                         '&client_id=YOUR_CLIENT_ID' +
                         '&client_secret=YOUR_CLIENT_SECRET' +
                         '&username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
                         '&password=' + EncodingUtil.urlEncode(password + securityToken, 'UTF-8');
            
            req.setBody(body);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                currentLogin++;
                System.debug('Created login #' + currentLogin + ' for user: ' + username);
                
                // Continue with next login
                if (currentLogin < loginCount) {
                    System.enqueueJob(this);
                }
            } else {
                System.debug('Error creating login: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception creating login: ' + e.getMessage());
            // Note: In test context, callouts are mocked, so this won't create real logins
        }
    }
    
    /**
     * Static helper method to create logins for multiple users
     */
    public static void createLoginsForUsers(Map<Id, Integer> userLoginCounts) {
        for (Id userId : userLoginCounts.keySet()) {
            LoginHistoryTestDataCreator creator = new LoginHistoryTestDataCreator(userId, userLoginCounts.get(userId));
            System.enqueueJob(creator);
        }
    }
}

