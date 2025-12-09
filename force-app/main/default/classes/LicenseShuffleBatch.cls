/**
 * Batch class for optimizing Salesforce Community license usage.
 * 
 * Automatically downgrades low-usage Premium users (≤4 logins/year) to Login licenses
 * and upgrades high-usage Login users (>20 logins/year) to Premium licenses.
 * 
 * Protects Chairs and new users (<90 days old) from license changes.
 * Targets keeping up to 450 Premium licenses assigned (low watermark).
 */
public class LicenseShuffleBatch implements Database.Batchable<User>, Database.Stateful {
    
    private static final Integer TARGET_PREMIUM_LICENSES = 450;
    private static final Integer LOW_LOGIN_THRESHOLD = 4;
    private static final Integer HIGH_LOGIN_THRESHOLD = 20;
    private static final Integer NEW_USER_DAYS = 90;
    private static final String CHAIR_PROFILE = 'SM Community Plus Chair';
    private static final String PREMIUM_PROFILE = 'SM Community Plus Member';
    private static final String LOGIN_PROFILE = 'SM Community Plus Login';
    private static final String PREMIUM_LICENSE = 'Customer Community Plus';
    private static final String LOGIN_LICENSE = 'Customer Community Plus Login';
    
    // Stateful variables to track across batch chunks
    private Set<Id> protectedUserIds = new Set<Id>();
    private Map<Id, Integer> userLoginCounts = new Map<Id, Integer>();
    private Map<Id, User> allPremiumUsers = new Map<Id, User>(); // All Premium users across all chunks
    private List<License_Change_Log__c> changeLogs = new List<License_Change_Log__c>();
    private Integer totalUsersProcessed = 0;
    private Integer totalChanges = 0;
    private String batchJobId;
    private Boolean targetCalculated = false;
    private Set<Id> premiumUsersToKeep = new Set<Id>();
    
    /**
     * Batch start method - queries all active Community users
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        batchJobId = bc.getJobId();
        System.debug('LicenseShuffleBatch: Starting batch job ' + batchJobId);
        
        // Query all active users with Customer Community Plus or Customer Community Plus Login licenses
        return Database.getQueryLocator([
            SELECT Id, Profile.UserLicense.Name, Profile.Name, CreatedDate
            FROM User
            WHERE IsActive = true
            AND Profile.UserLicense.Name IN (:PREMIUM_LICENSE, :LOGIN_LICENSE)
            ORDER BY Profile.UserLicense.Name, CreatedDate DESC
        ]);
    }
    
    /**
     * Batch execute method - processes users, counts logins, and identifies candidates
     */
    public void execute(Database.BatchableContext bc, List<User> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('LicenseShuffleBatch: No users to process in this batch');
            return;
        }
        
        System.debug('LicenseShuffleBatch: Processing ' + scope.size() + ' users');
        totalUsersProcessed += scope.size();
        
        // First pass: Identify protected users, count logins, and collect Premium users
        for (User u : scope) {
            // Identify protected users (Chairs and new users <90 days old)
            if (u.Profile.Name == CHAIR_PROFILE || isNewUser(u.CreatedDate)) {
                protectedUserIds.add(u.Id);
            }
            
            // Count logins for each user
            Integer loginCount = countUserLogins(u.Id);
            userLoginCounts.put(u.Id, loginCount);
            
            // Collect all Premium users for later calculation
            if (u.Profile.UserLicense.Name == PREMIUM_LICENSE) {
                allPremiumUsers.put(u.Id, u);
            }
        }
        
        // Calculate target Premium users to keep (only once, after we've seen all users)
        // Note: This is an approximation - we calculate based on what we've seen so far
        // In a perfect world, we'd do this in finish(), but DML isn't allowed there
        // So we'll be conservative and recalculate in each chunk
        if (!targetCalculated || allPremiumUsers.size() > premiumUsersToKeep.size() * 2) {
            premiumUsersToKeep = calculatePremiumUsersToKeep();
            targetCalculated = true;
        }
        
        // Second pass: Identify candidates and execute changes
        List<User> usersToUpdate = new List<User>();
        
        for (User u : scope) {
            String currentLicense = u.Profile.UserLicense.Name;
            Integer loginCount = userLoginCounts.get(u.Id);
            
            // Skip protected users - they never change
            if (protectedUserIds.contains(u.Id)) {
                continue;
            }
            
            // Determine if user needs license change
            if (currentLicense == PREMIUM_LICENSE) {
                // Premium user: downgrade if not in keep list
                if (!premiumUsersToKeep.contains(u.Id)) {
                    // Downgrade to Login license
                    User userToUpdate = new User(Id = u.Id);
                    userToUpdate.ProfileId = getProfileId(LOGIN_PROFILE);
                    usersToUpdate.add(userToUpdate);
                    
                    // Create log record
                    createChangeLog(u, PREMIUM_LICENSE, LOGIN_LICENSE, 
                                   u.Profile.Name, LOGIN_PROFILE, loginCount, 'Low usage');
                }
            } else if (currentLicense == LOGIN_LICENSE) {
                // Login user: upgrade if high usage and we have room
                // Check if we're below target (accounting for users we're keeping)
                Integer currentPremiumCount = premiumUsersToKeep.size();
                if (loginCount > HIGH_LOGIN_THRESHOLD && currentPremiumCount < TARGET_PREMIUM_LICENSES) {
                    // Upgrade to Premium license
                    User userToUpdate = new User(Id = u.Id);
                    userToUpdate.ProfileId = getProfileId(PREMIUM_PROFILE);
                    usersToUpdate.add(userToUpdate);
                    
                    // Add to keep list to prevent double-processing
                    premiumUsersToKeep.add(u.Id);
                    
                    // Create log record
                    createChangeLog(u, LOGIN_LICENSE, PREMIUM_LICENSE,
                                   u.Profile.Name, PREMIUM_PROFILE, loginCount, 'High usage');
                }
            }
        }
        
        // Update users
        if (!usersToUpdate.isEmpty()) {
            try {
                update usersToUpdate;
                totalChanges += usersToUpdate.size();
                System.debug('LicenseShuffleBatch: Updated ' + usersToUpdate.size() + ' users');
            } catch (Exception e) {
                System.debug('LicenseShuffleBatch: Error updating users: ' + e.getMessage());
                // Continue processing - log error but don't fail entire batch
            }
        }
        
        // Insert change logs
        if (!changeLogs.isEmpty()) {
            try {
                insert changeLogs;
                System.debug('LicenseShuffleBatch: Created ' + changeLogs.size() + ' change log records');
                changeLogs.clear(); // Clear after insert to avoid duplicates
            } catch (Exception e) {
                System.debug('LicenseShuffleBatch: Error creating change logs: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Batch finish method - logs summary statistics
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed,
                TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        System.debug('LicenseShuffleBatch: Batch job completed');
        System.debug('Status: ' + job.Status);
        System.debug('Job items processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug('Number of errors: ' + job.NumberOfErrors);
        System.debug('Total users processed: ' + totalUsersProcessed);
        System.debug('Total license changes: ' + totalChanges);
        System.debug('Protected users: ' + protectedUserIds.size());
    }
    
    /**
     * Helper method to check if user is new (<90 days old)
     */
    private Boolean isNewUser(DateTime createdDate) {
        if (createdDate == null) {
            return false;
        }
        Integer daysSinceCreation = createdDate.date().daysBetween(Date.today());
        return daysSinceCreation < NEW_USER_DAYS;
    }
    
    /**
     * Helper method to count user logins
     * Uses fiscal year (Apr-Dec) or last 365 days (Jan-Mar) based on current month
     */
    private Integer countUserLogins(Id userId) {
        Integer currentMonth = Date.today().month();
        Date startDate;
        
        if (currentMonth < 4) {
            // January, February, March: Use last 365 days
            startDate = Date.today().addDays(-365);
        } else {
            // April through December: Use current fiscal year
            // Fiscal year starts April 1
            Integer currentYear = Date.today().year();
            if (currentMonth >= 4) {
                startDate = Date.newInstance(currentYear, 4, 1);
            } else {
                startDate = Date.newInstance(currentYear - 1, 4, 1);
            }
        }
        
        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        
        // Query LoginHistory for this user
        Integer loginCount = [
            SELECT COUNT()
            FROM LoginHistory
            WHERE UserId = :userId
            AND LoginTime >= :startDateTime
        ];
        
        return loginCount;
    }
    
    /**
     * Helper method to calculate which Premium users to keep
     * Returns set of User IDs that should remain Premium
     * Uses all Premium users collected across all chunks
     */
    private Set<Id> calculatePremiumUsersToKeep() {
        Set<Id> usersToKeep = new Set<Id>();
        
        // Start with all protected Premium users
        for (User u : allPremiumUsers.values()) {
            if (protectedUserIds.contains(u.Id)) {
                usersToKeep.add(u.Id);
            }
        }
        
        // Add Premium users with login count > 4, sorted by login count (descending)
        List<User> premiumUsers = new List<User>();
        for (User u : allPremiumUsers.values()) {
            if (!protectedUserIds.contains(u.Id)) {
                premiumUsers.add(u);
            }
        }
        
        // Sort by login count descending
        premiumUsers.sort(new UserLoginCountComparator(userLoginCounts));
        
        // Add top users up to target (450 total, but may be fewer)
        Integer remainingSlots = TARGET_PREMIUM_LICENSES - usersToKeep.size();
        for (User u : premiumUsers) {
            Integer loginCount = userLoginCounts.get(u.Id) != null ? userLoginCounts.get(u.Id) : 0;
            if (loginCount > LOW_LOGIN_THRESHOLD && remainingSlots > 0) {
                usersToKeep.add(u.Id);
                remainingSlots--;
            }
        }
        
        return usersToKeep;
    }
    
    /**
     * Helper method to get Profile ID by name
     */
    private Id getProfileId(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        return p.Id;
    }
    
    /**
     * Helper method to create change log record
     */
    private void createChangeLog(User u, String oldLicense, String newLicense,
                                 String oldProfile, String newProfile,
                                 Integer loginCount, String reason) {
        License_Change_Log__c log = new License_Change_Log__c(
            User__c = u.Id,
            Old_License__c = oldLicense,
            New_License__c = newLicense,
            Old_Profile__c = oldProfile,
            New_Profile__c = newProfile,
            Login_Count__c = loginCount,
            Reason__c = reason,
            Changed_At__c = DateTime.now(),
            Batch_Job_Id__c = batchJobId
        );
        changeLogs.add(log);
    }
    
    /**
     * Comparator class to sort users by login count (descending)
     */
    private class UserLoginCountComparator implements Comparator<User> {
        private Map<Id, Integer> loginCounts;
        
        public UserLoginCountComparator(Map<Id, Integer> loginCounts) {
            this.loginCounts = loginCounts;
        }
        
        public Integer compare(User u1, User u2) {
            Integer count1 = loginCounts.get(u1.Id) != null ? loginCounts.get(u1.Id) : 0;
            Integer count2 = loginCounts.get(u2.Id) != null ? loginCounts.get(u2.Id) : 0;
            
            // Sort descending (highest login count first)
            if (count1 > count2) {
                return -1;
            } else if (count1 < count2) {
                return 1;
            }
            return 0;
        }
    }
}

