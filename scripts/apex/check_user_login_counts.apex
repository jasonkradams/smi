// Check Users' current state and login count
Id userId = '0052G00000AVquPQAT';

// Get user info
User user = [
    SELECT Id, Name, Profile.Name, Profile.UserLicense.Name, CreatedDate
    FROM User
    WHERE Id = :userId
];

System.debug('=== Users Current State ===');
System.debug('Name: ' + user.Name);
System.debug('Profile: ' + user.Profile.Name);
System.debug('License: ' + user.Profile.UserLicense.Name);
System.debug('Created: ' + user.CreatedDate);
System.debug('Days since creation: ' + user.CreatedDate.date().daysBetween(Date.today()));

// Count logins (fiscal year or last 365 days)
Date startDate;
Integer currentMonth = Date.today().month();
if (currentMonth < 4) {
    // Jan-Mar: use last 365 days
    startDate = Date.today().addDays(-365);
} else {
    // Apr-Dec: use current fiscal year (starts April 1)
    Integer currentYear = Date.today().year();
    startDate = Date.newInstance(currentYear, 4, 1);
}

DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));

Integer loginCount = [
    SELECT COUNT()
    FROM LoginHistory
    WHERE UserId = :userId
    AND LoginTime >= :startDateTime
];

System.debug('Login count (period: ' + startDate + ' to ' + Date.today() + '): ' + loginCount);

// Check if he's protected
Boolean isChair = user.Profile.Name == 'SM Community Plus Chair';
Boolean isNew = user.CreatedDate.date().daysBetween(Date.today()) < 90;
System.debug('Is Chair: ' + isChair);
System.debug('Is New (<90 days): ' + isNew);
System.debug('Is Protected: ' + (isChair || isNew));

// Check if he should be Premium or Login
System.debug('---');
System.debug('Should be Premium if:');
System.debug('  - Protected (Chair or <90 days): ' + (isChair || isNew));
System.debug('  - Login count > 4: ' + (loginCount > 4));
System.debug('  - In top 450 Premium users by login count');

