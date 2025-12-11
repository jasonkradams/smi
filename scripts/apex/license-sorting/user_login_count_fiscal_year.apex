// Anonymous Apex script to log User.Id, User.Name (first and last), and login count for fiscal year

// ============================================
// Determine Fiscal Year Date Range
// ============================================
Integer currentMonth = Date.today().month();
Date startDate;
String dateRange;

if (currentMonth < 4) {
    // January, February, March: Use last 365 days
    startDate = Date.today().addDays(-365);
    dateRange = 'Last 365 days';
} else {
    // April through December: Use current fiscal year (starts April 1)
    Integer currentYear = Date.today().year();
    startDate = Date.newInstance(currentYear, 1, 1);
    dateRange = 'Current Fiscal Year (from January 1, ' + currentYear + ')';
}

DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));

// ============================================
// Get Active Users with Specific Profiles Only
// ============================================
// Only include these profiles (excludes System Administrator):
// - SM Community Plus Login
// - SM Community Plus Member
// - SM Community Plus Chair
List<User> users = [
    SELECT Id, FirstName, LastName, Name, Profile.Name
    FROM User
    WHERE IsActive = true
    AND Profile.Name IN ('SM Community Plus Login', 'SM Community Plus Member', 'SM Community Plus Chair')
];

if (users.isEmpty()) {
    System.debug('No active users found.');
    return;
}

Set<Id> userIds = new Set<Id>();
for (User u : users) {
    userIds.add(u.Id);
}

// ============================================
// Count Logins by User (Aggregate Query)
// ============================================
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
// Sort Users by Login Count (Descending)
// ============================================
// Create list of maps with user and login count for sorting
List<Map<String, Object>> usersWithCounts = new List<Map<String, Object>>();
for (User u : users) {
    Integer count = loginCounts.get(u.Id) != null ? loginCounts.get(u.Id) : 0;
    Map<String, Object> userMap = new Map<String, Object>();
    userMap.put('user', u);
    userMap.put('loginCount', count);
    usersWithCounts.add(userMap);
}

// Sort by login count descending using bubble sort
for (Integer i = 0; i < usersWithCounts.size() - 1; i++) {
    for (Integer j = 0; j < usersWithCounts.size() - i - 1; j++) {
        Integer count1 = (Integer)usersWithCounts[j].get('loginCount');
        Integer count2 = (Integer)usersWithCounts[j + 1].get('loginCount');
        User user1 = (User)usersWithCounts[j].get('user');
        User user2 = (User)usersWithCounts[j + 1].get('user');
        
        // Sort descending by login count
        if (count1 < count2 || (count1 == count2 && (user1.Name != null ? user1.Name : '').compareTo(user2.Name != null ? user2.Name : '') > 0)) {
            Map<String, Object> temp = usersWithCounts[j];
            usersWithCounts[j] = usersWithCounts[j + 1];
            usersWithCounts[j + 1] = temp;
        }
    }
}

// ============================================
// Log Results for Each User in Table Format
// ============================================
// Calculate column widths
Integer maxRowNumLength = 6; // For "Row #" header and row numbers
Integer maxIdLength = 18; // Salesforce Ids are 18 characters
Integer maxNameLength = 20;
Integer maxLoginCountLength = 5;

// Find maximum name length
for (Map<String, Object> userMap : usersWithCounts) {
    User u = (User)userMap.get('user');
    if (u.Name != null && u.Name.length() > maxNameLength) {
        maxNameLength = u.Name.length();
    }
}

// Ensure minimum widths
maxNameLength = Math.max(maxNameLength, 20);
maxLoginCountLength = Math.max(maxLoginCountLength, 12);

// Separator line
String separator = '+';
for (Integer i = 0; i < maxRowNumLength + 2; i++) separator += '-';
separator += '+';
for (Integer i = 0; i < maxIdLength + 2; i++) separator += '-';
separator += '+';
for (Integer i = 0; i < maxNameLength + 2; i++) separator += '-';
separator += '+';
for (Integer i = 0; i < maxLoginCountLength + 2; i++) separator += '-';
separator += '+';

System.debug('');
System.debug('========================================');
System.debug('User Login Count Report - Fiscal Year');
System.debug('Date Range: ' + dateRange);
System.debug('Period: ' + startDate + ' to ' + Date.today());
System.debug('Total Users: ' + users.size());
System.debug('========================================');
System.debug('');

// Print table header
System.debug(separator);
String headerRowNum = 'Row #'.rightPad(maxRowNumLength);
String headerId = 'User Id'.rightPad(maxIdLength);
String headerName = 'User Name'.rightPad(maxNameLength);
String headerCount = 'Login Count'.rightPad(maxLoginCountLength);
// Build pipe character as string to avoid encoding issues
String pipe = String.fromCharArray(new Integer[]{124});
String headerRow = pipe + ' ' + headerRowNum + ' ' + pipe + ' ' + headerId + ' ' + pipe + ' ' + headerName + ' ' + pipe + ' ' + headerCount + ' ' + pipe;
System.debug(headerRow);
System.debug(separator);

// Print table rows
Integer rowNumber = 1;
for (Map<String, Object> userMap : usersWithCounts) {
    User u = (User)userMap.get('user');
    Integer loginCount = (Integer)userMap.get('loginCount');
    
    String rowNumStr = String.valueOf(rowNumber);
    String userId = String.valueOf(u.Id);
    String userName = u.Name != null ? u.Name : '';
    String loginCountStr = String.valueOf(loginCount);
    
    // Pad each column
    String paddedRowNum = rowNumStr.rightPad(maxRowNumLength);
    String paddedId = userId.rightPad(maxIdLength);
    String paddedName = userName.rightPad(maxNameLength);
    String paddedCount = loginCountStr.rightPad(maxLoginCountLength);
    
    // Build pipe character as string to avoid encoding issues
    String row = pipe + ' ' + paddedRowNum + ' ' + pipe + ' ' + paddedId + ' ' + pipe + ' ' + paddedName + ' ' + pipe + ' ' + paddedCount + ' ' + pipe;
    System.debug(row);
    rowNumber++;
}

// Print table footer
System.debug(separator);

System.debug('');
System.debug('========================================');
System.debug('Report Complete');
System.debug('========================================');
