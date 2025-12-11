// Script to verify LoginHistory records for test users
// Run this after creating login records to verify they exist

// ============================================
// Configuration
// ============================================
String usernamePattern = 'test.%@spokanemountaineers.org.test';

// ============================================
// Get Test Users
// ============================================
List<User> testUsers = [
    SELECT Id, Username, Email, Profile.Name, Profile.UserLicense.Name, CreatedDate
    FROM User
    WHERE Username LIKE :usernamePattern
    AND IsActive = true
    ORDER BY Username
];

if (testUsers.isEmpty()) {
    System.debug('No test users found.');
    return;
}

Set<Id> userIds = new Set<Id>();
for (User u : testUsers) {
    userIds.add(u.Id);
}

// ============================================
// Count Logins by User
// ============================================
// Determine date range based on current month
Integer currentMonth = Date.today().month();
Date startDate;
String dateRange;

if (currentMonth < 4) {
    // January, February, March: Use last 365 days
    startDate = Date.today().addDays(-365);
    dateRange = 'LAST_N_DAYS:365';
} else {
    // April through December: Use current fiscal year
    Integer currentYear = Date.today().year();
    startDate = Date.newInstance(currentYear, 4, 1);
    dateRange = 'THIS_FISCAL_YEAR';
}

DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));

// Query LoginHistory
Map<Id, Integer> loginCounts = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT UserId, COUNT(Id) loginCount
    FROM LoginHistory
    WHERE UserId IN :userIds
    AND LoginTime >= :startDateTime
    GROUP BY UserId
]) {
    loginCounts.put((Id)ar.get('UserId'), (Integer)ar.get('loginCount'));
}

// ============================================
// Output Results
// ============================================
System.debug('');
System.debug('========================================');
System.debug('Login History Report');
System.debug('Date Range: ' + dateRange + ' (from ' + startDate + ')');
System.debug('========================================');
System.debug('');

Integer totalLogins = 0;
for (User u : testUsers) {
    Integer count = loginCounts.get(u.Id) != null ? loginCounts.get(u.Id) : 0;
    totalLogins += count;
    
    String userType = '';
    if (u.Username.contains('highusage')) {
        userType = 'High Usage (Premium) - Target: 25+';
    } else if (u.Username.contains('lowpremium')) {
        userType = 'Low Usage (Premium) - Target: 2-4';
    } else if (u.Username.contains('highlogin')) {
        userType = 'High Usage (Login) - Target: 20+';
    } else if (u.Username.contains('chair')) {
        userType = 'Chair (Protected) - Target: 10+';
    } else if (u.Username.contains('newuser')) {
        userType = 'New User (Protected) - Target: 5+';
    }
    
    System.debug('User: ' + u.Username);
    System.debug('  Type: ' + userType);
    System.debug('  License: ' + u.Profile.UserLicense.Name);
    System.debug('  Profile: ' + u.Profile.Name);
    System.debug('  Created: ' + u.CreatedDate);
    System.debug('  Login Count: ' + count);
    System.debug('  Status: ' + (count > 0 ? '✓ Has logins' : '✗ No logins'));
    System.debug('');
}

System.debug('========================================');
System.debug('Total Users: ' + testUsers.size());
System.debug('Total Logins: ' + totalLogins);
System.debug('Average Logins per User: ' + (testUsers.size() > 0 ? totalLogins / testUsers.size() : 0));
System.debug('========================================');

// ============================================
// Recommendations
// ============================================
if (totalLogins == 0) {
    System.debug('');
    System.debug('WARNING: No LoginHistory records found!');
    System.debug('Run create_login_history_helper.apex to create logins.');
} else {
    System.debug('');
    System.debug('SUCCESS: LoginHistory records found.');
    System.debug('You can now run the LicenseShuffleBatch to test license sorting.');
}

