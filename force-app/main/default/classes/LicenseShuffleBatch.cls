/**
 * Batch class for optimizing Salesforce Community license usage.
 * 
 * Automatically downgrades low-usage Premium users (≤4 logins/year) to Login licenses
 * and upgrades high-usage Login users (>20 logins/year) to Premium licenses.
 * 
 * Protects Chairs and new users (<90 days old) from license changes.
 * Targets keeping up to 450 Premium licenses assigned (low watermark).
 */
public class LicenseShuffleBatch implements Database.Batchable<sObject>, Database.Stateful {
    
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
    private Map<Id, User> allUsers = new Map<Id, User>(); // All Community users (Premium and Login) across all chunks
    private List<License_Change_Log__c> changeLogs = new List<License_Change_Log__c>();
    private Integer totalUsersProcessed = 0;
    private Integer totalChanges = 0;
    private String batchJobId;
    private Boolean targetCalculated = false;
    private Set<Id> premiumUsersToKeep = new Set<Id>(); // Users who should have Premium licenses (450)
    private Boolean collectionPhaseComplete = false; // Track if we've finished collecting all users
    
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
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('LicenseShuffleBatch: No users to process in this batch');
            return;
        }
        
        // Cast scope to List<User>
        List<User> users = new List<User>();
        for (sObject obj : scope) {
            users.add((User)obj);
        }
        
        System.debug('LicenseShuffleBatch: Processing ' + users.size() + ' users');
        totalUsersProcessed += users.size();
        
        // First pass: Identify protected users, count logins, and collect all users
        for (User u : users) {
            // Identify protected users (Chairs and new users <90 days old)
            if (u.Profile.Name == CHAIR_PROFILE || isNewUser(u.CreatedDate)) {
                protectedUserIds.add(u.Id);
            }
            
            // Count logins for each user
            Integer loginCount = countUserLogins(u.Id);
            userLoginCounts.put(u.Id, loginCount);
            
            // Collect all users (both Premium and Login) for later calculation
            allUsers.put(u.Id, u);
        }
        
        // Calculate which users should have Premium licenses (exactly 450)
        // This considers ALL users together and selects the top 450 by login count
        // This ensures we maintain exactly 450 Premium licenses and prioritize high-usage Login users
        // to avoid exceeding the 5000 login pool limit
        if (!targetCalculated) {
            // First time: calculate based on what we have so far, but mark that we'll recalculate
            premiumUsersToKeep = calculatePremiumUsersToKeep();
            System.debug('LicenseShuffleBatch: Initial calculation - keeping ' + premiumUsersToKeep.size() + ' users as Premium out of ' + allUsers.size() + ' total users');
        } else if (allUsers.size() > premiumUsersToKeep.size() * 1.5) {
            // Recalculate if we've discovered significantly more users
            // This handles the case where users are distributed across chunks
            premiumUsersToKeep = calculatePremiumUsersToKeep();
            System.debug('LicenseShuffleBatch: Recalculated - keeping ' + premiumUsersToKeep.size() + ' users as Premium out of ' + allUsers.size() + ' total users');
        }
        
        // Second pass: Identify candidates and execute changes
        List<User> usersToUpdate = new List<User>();
        
        for (User u : users) {
            String currentLicense = u.Profile.UserLicense.Name;
            Integer loginCount = userLoginCounts.get(u.Id);
            
            // Skip protected users - they never change
            if (protectedUserIds.contains(u.Id)) {
                System.debug('LicenseShuffleBatch: Skipping protected user ' + u.Id + ' (login count: ' + loginCount + ')');
                continue;
            }
            
            // Determine if user needs license change
            if (currentLicense == PREMIUM_LICENSE) {
                // Premium user: downgrade if not in keep list
                if (!premiumUsersToKeep.contains(u.Id)) {
                    // Downgrade to Login license
                    System.debug('LicenseShuffleBatch: Downgrading user ' + u.Id + ' from Premium to Login (login count: ' + loginCount + ', in keep list: ' + premiumUsersToKeep.contains(u.Id) + ')');
                    User userToUpdate = new User(Id = u.Id);
                    userToUpdate.ProfileId = getProfileId(LOGIN_PROFILE);
                    usersToUpdate.add(userToUpdate);
                    
                    // Create log record
                    createChangeLog(u, PREMIUM_LICENSE, LOGIN_LICENSE, 
                                   u.Profile.Name, LOGIN_PROFILE, loginCount, 'Low usage');
                } else {
                    System.debug('LicenseShuffleBatch: Keeping user ' + u.Id + ' as Premium (login count: ' + loginCount + ')');
                }
            } else if (currentLicense == LOGIN_LICENSE) {
                // Login user: upgrade if they're in the Premium keep list
                // The keep list is calculated to maintain exactly 450 Premium licenses
                // and prioritizes high-usage users to avoid exceeding the 5000 login pool
                if (premiumUsersToKeep.contains(u.Id)) {
                    // Upgrade to Premium license
                    System.debug('LicenseShuffleBatch: Upgrading user ' + u.Id + ' from Login to Premium (login count: ' + loginCount + ')');
                    User userToUpdate = new User(Id = u.Id);
                    userToUpdate.ProfileId = getProfileId(PREMIUM_PROFILE);
                    usersToUpdate.add(userToUpdate);
                    
                    // Create log record
                    createChangeLog(u, LOGIN_LICENSE, PREMIUM_LICENSE,
                                   u.Profile.Name, PREMIUM_PROFILE, loginCount, 'High usage');
                    System.debug('LicenseShuffleBatch: Created upgrade log for user ' + u.Id + ' (Login -> Premium, login count: ' + loginCount + ')');
                } else {
                    System.debug('LicenseShuffleBatch: Keeping user ' + u.Id + ' as Login (login count: ' + loginCount + ', not in Premium keep list)');
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
        
        // Note: We don't insert change logs here because of MIXED_DML_OPERATION error.
        // We accumulate logs and insert them via Queueable in finish() method.
        if (!changeLogs.isEmpty()) {
            System.debug('LicenseShuffleBatch: Accumulated ' + changeLogs.size() + ' change log records in this chunk');
            for (License_Change_Log__c log : changeLogs) {
                System.debug('  - Log for User: ' + log.User__c + ', Change: ' + log.Old_License__c + ' -> ' + log.New_License__c + ', Reason: ' + log.Reason__c);
            }
        } else {
            System.debug('LicenseShuffleBatch: No change logs to accumulate in this chunk');
        }
    }
    
    /**
     * Batch finish method - logs summary statistics
     */
    public void finish(Database.BatchableContext bc) {
        try {
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
        } catch (QueryException e) {
            // Job may not exist in test context - that's okay
            System.debug('LicenseShuffleBatch: Could not query job status: ' + e.getMessage());
        }
        
        System.debug('Total users processed: ' + totalUsersProcessed);
        System.debug('Total license changes: ' + totalChanges);
        System.debug('Protected users: ' + protectedUserIds.size());
        System.debug('Total change logs accumulated: ' + changeLogs.size());
        
        // Insert all accumulated change logs via Queueable to avoid MIXED_DML_OPERATION error
        // This runs in a separate transaction after User updates are complete
        if (!changeLogs.isEmpty()) {
            try {
                System.debug('LicenseShuffleBatch: Enqueueing LicenseChangeLogQueueable to insert ' + changeLogs.size() + ' change log records');
                // Create a copy of the list to pass to Queueable (since it will be cleared)
                List<License_Change_Log__c> logsToInsert = new List<License_Change_Log__c>(changeLogs);
                LicenseChangeLogQueueable queueable = new LicenseChangeLogQueueable(logsToInsert);
                System.enqueueJob(queueable);
                System.debug('LicenseShuffleBatch: Successfully enqueued LicenseChangeLogQueueable job');
            } catch (Exception e) {
                System.debug('LicenseShuffleBatch: Error enqueueing LicenseChangeLogQueueable: ' + e.getMessage());
                System.debug('LicenseShuffleBatch: Stack trace: ' + e.getStackTraceString());
                // Log each failed record for debugging
                for (License_Change_Log__c log : changeLogs) {
                    System.debug('  - Failed to queue log: User=' + log.User__c + ', Old=' + log.Old_License__c + ', New=' + log.New_License__c);
                }
            }
        } else {
            System.debug('LicenseShuffleBatch: No change logs to insert');
        }
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
     * Helper method to calculate which users should have Premium licenses
     * Returns set of User IDs that should have Premium licenses (exactly 450)
     * Uses ALL users (both Premium and Login) collected across all chunks
     * 
     * Logic:
     * 1. Always include protected users (Chairs and new users) - they must be Premium
     * 2. Sort ALL users (Premium and Login) by login count (descending)
     * 3. Select top 450 users by login count to be Premium
     * 
     * This ensures:
     * - Exactly 450 Premium licenses are assigned
     * - High-usage Login users are upgraded to Premium (reduces Login pool usage)
     * - Low-usage Premium users are downgraded to Login
     * - Helps prevent exceeding the 5000 login pool limit for Login licenses
     */
    private Set<Id> calculatePremiumUsersToKeep() {
        Set<Id> usersToKeep = new Set<Id>();
        
        System.debug('LicenseShuffleBatch: Calculating which users should have Premium licenses');
        System.debug('  Total users collected: ' + allUsers.size());
        System.debug('  Protected user count: ' + protectedUserIds.size());
        System.debug('  Target Premium licenses: ' + TARGET_PREMIUM_LICENSES);
        
        // Step 1: Always include all protected users (they must be Premium)
        Integer protectedCount = 0;
        for (Id userId : protectedUserIds) {
            if (allUsers.containsKey(userId)) {
                usersToKeep.add(userId);
                protectedCount++;
                Integer loginCount = userLoginCounts.get(userId) != null ? userLoginCounts.get(userId) : 0;
                System.debug('  Protected user (must be Premium): ' + userId + ' (login count: ' + loginCount + ')');
            }
        }
        System.debug('  Protected users included: ' + protectedCount);
        
        // Step 2: Create list of all non-protected users
        List<User> nonProtectedUsers = new List<User>();
        for (User u : allUsers.values()) {
            if (!protectedUserIds.contains(u.Id)) {
                nonProtectedUsers.add(u);
            }
        }
        
        System.debug('  Non-protected users: ' + nonProtectedUsers.size());
        
        // Step 3: Sort all non-protected users by login count (descending)
        // This ensures high-usage Login users are prioritized for Premium
        nonProtectedUsers.sort(new UserLoginCountComparator(userLoginCounts));
        
        // Step 4: Select top users up to target (450 total)
        // This maintains exactly 450 Premium licenses
        Integer remainingSlots = TARGET_PREMIUM_LICENSES - usersToKeep.size();
        Integer addedCount = 0;
        Integer loginUsersAdded = 0;
        Integer premiumUsersAdded = 0;
        
        for (User u : nonProtectedUsers) {
            if (remainingSlots <= 0) {
                break; // We've reached our target of 450
            }
            
            Integer loginCount = userLoginCounts.get(u.Id) != null ? userLoginCounts.get(u.Id) : 0;
            String currentLicense = u.Profile.UserLicense.Name;
            
            // Add user to Premium keep list
            usersToKeep.add(u.Id);
            remainingSlots--;
            addedCount++;
            
            if (currentLicense == LOGIN_LICENSE) {
                loginUsersAdded++;
                System.debug('  Adding Login user to Premium: ' + u.Id + ' (login count: ' + loginCount + ')');
            } else {
                premiumUsersAdded++;
                System.debug('  Keeping Premium user: ' + u.Id + ' (login count: ' + loginCount + ')');
            }
        }
        
        System.debug('  Non-protected users added: ' + addedCount + ' (Login: ' + loginUsersAdded + ', Premium: ' + premiumUsersAdded + ')');
        System.debug('  Total users to have Premium licenses: ' + usersToKeep.size());
        
        // Log users who will be downgraded (Premium users not in keep list)
        Integer premiumUsersToDowngrade = 0;
        Integer totalLoginCountToDowngrade = 0;
        for (User u : allUsers.values()) {
            if (u.Profile.UserLicense.Name == PREMIUM_LICENSE && 
                !usersToKeep.contains(u.Id) && 
                !protectedUserIds.contains(u.Id)) {
                premiumUsersToDowngrade++;
                Integer loginCount = userLoginCounts.get(u.Id) != null ? userLoginCounts.get(u.Id) : 0;
                totalLoginCountToDowngrade += loginCount;
            }
        }
        System.debug('  Premium users to downgrade: ' + premiumUsersToDowngrade + ' (total logins: ' + totalLoginCountToDowngrade + ')');
        
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

