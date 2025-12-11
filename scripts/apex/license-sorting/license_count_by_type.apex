// Apex to find all Customer Community Plus (Premium)
// and Customer Community Plus Login (cheap) profiles.
// -------------------------------------------
// 1. Load active users + license types
// -------------------------------------------
Map<Id, String> userToLicense = new Map<Id, String>();

for (User u : [
    SELECT Id, Profile.UserLicense.Name
    FROM User
    WHERE IsActive = TRUE
        AND Profile.UserLicense.Name IN (
            'Customer Community Plus',
            'Customer Community Plus Login'
        )
]) {
    userToLicense.put(u.Id, u.Profile.UserLicense.Name);
}

// Initialize counters
Map<String, Integer> loginCounts = new Map<String, Integer>{
    'Customer Community Plus' => 0,
    'Customer Community Plus Login' => 0
};

// -------------------------------------------
// 2. Count logins via LoginHistory
// -------------------------------------------
for (LoginHistory lh : [
    SELECT UserId
    FROM LoginHistory
    WHERE LoginTime = THIS_FISCAL_YEAR
]) {
    if (userToLicense.containsKey(lh.UserId)) {
        String license = userToLicense.get(lh.UserId);
        loginCounts.put(license, loginCounts.get(license) + 1);
    }
}

// -------------------------------------------
// 3. Count users per license (optional)
// -------------------------------------------
Integer plusUsers = 0;
Integer loginUsers = 0;

for (String license : userToLicense.values()) {
    if (license == 'Customer Community Plus') plusUsers++;
    else if (license == 'Customer Community Plus Login') loginUsers++;
}

// -------------------------------------------
// 4. Output
// -------------------------------------------
System.debug('--- User Counts ---');
System.debug('Customer Community Plus Users:       ' + plusUsers);
System.debug('Customer Community Plus Login Users: ' + loginUsers);

System.debug('--- Login Counts (This Fiscal Year) ---');
System.debug('Customer Community Plus:       ' + loginCounts.get('Customer Community Plus'));
System.debug('Customer Community Plus Login: ' + loginCounts.get('Customer Community Plus Login'));
