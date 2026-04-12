/**
 * Emergency script: downgrade the 30 non-protected Premium users with the lowest
 * fiscal-year login counts to Customer Community Plus Login.
 *
 * Run this in Anonymous Apex when the Premium license cap (475) has been exceeded.
 *
 * Safe to re-run — users already on Login license are excluded from the query.
 */

System.debug('=== Emergency License Downgrade: Bottom 30 ===');

// --- Fiscal year date range (matches LicenseShuffleBatch.countUserLogins logic) ---
Integer currentMonth = Date.today().month();
Integer currentYear = Date.today().year();
Date startDate;
if (currentMonth >= 2 && currentMonth <= 4) {
    startDate = Date.today().addDays(-365);
} else if (currentMonth >= 5) {
    startDate = Date.newInstance(currentYear, 2, 1);
} else {
    startDate = Date.newInstance(currentYear - 1, 2, 1);
}
DateTime startDT = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
System.debug('Fiscal period start: ' + startDate);

// --- Build login count map from Fiscal_Year_Login_History__c ---
AggregateResult[] loginAggs = [
    SELECT User__c uid, COUNT(Id) cnt
    FROM Fiscal_Year_Login_History__c
    WHERE Login_Time__c >= :startDT
    GROUP BY User__c
];
Map<Id, Integer> loginMap = new Map<Id, Integer>();
for (AggregateResult ar : loginAggs) {
    loginMap.put((Id)ar.get('uid'), (Integer)ar.get('cnt'));
}
System.debug('Users with login records: ' + loginMap.size());

// --- Query all non-protected active Premium users ---
Date cutoff = Date.today().addDays(-90);
DateTime cutoffDT = DateTime.newInstance(cutoff, Time.newInstance(0, 0, 0, 0));
List<User> premiumUsers = [
    SELECT Id, Name, Profile.Name, Profile.UserLicense.Name, CreatedDate
    FROM User
    WHERE IsActive = true
    AND Profile.UserLicense.Name = 'Customer Community Plus'
    AND Profile.Name != 'SM Community Plus Chair'
    AND CreatedDate < :cutoffDT
];
System.debug('Non-protected Premium users: ' + premiumUsers.size());

// --- Sort by login count ascending ---
premiumUsers.sort(new AscLoginCountComparator(loginMap));

// --- Take the bottom 30 ---
Integer TARGET = 30;
List<User> toDowngrade = new List<User>();
System.debug('--- Bottom 30 users to downgrade ---');
for (Integer i = 0; i < Math.min(TARGET, premiumUsers.size()); i++) {
    User u = premiumUsers[i];
    Integer cnt = loginMap.containsKey(u.Id) ? loginMap.get(u.Id) : 0;
    System.debug((i + 1) + '. ' + u.Name + ' | Logins: ' + cnt + ' | Created: ' + u.CreatedDate.date());
    toDowngrade.add(u);
}

if (toDowngrade.isEmpty()) {
    System.debug('No users to downgrade. Exiting.');
    return;
}

// --- Look up the Login profile ID ---
Profile loginProfile = [SELECT Id FROM Profile WHERE Name = 'SM Community Plus Login' LIMIT 1];
System.debug('Login profile ID: ' + loginProfile.Id);

// --- Build user updates and change log records ---
List<User> usersToUpdate = new List<User>();
List<License_Change_Log__c> logs = new List<License_Change_Log__c>();
String jobId = 'EMERGENCY-' + DateTime.now().format('yyyyMMdd-HHmmss');

for (User u : toDowngrade) {
    Integer cnt = loginMap.containsKey(u.Id) ? loginMap.get(u.Id) : 0;
    User upd = new User(Id = u.Id, ProfileId = loginProfile.Id);
    usersToUpdate.add(upd);
    logs.add(new License_Change_Log__c(
        User__c = u.Id,
        Old_License__c = 'Customer Community Plus',
        New_License__c = 'Customer Community Plus Login',
        Old_Profile__c = u.Profile.Name,
        New_Profile__c = 'SM Community Plus Login',
        Login_Count__c = cnt,
        Reason__c = 'Emergency downgrade - license cap exceeded',
        Changed_At__c = DateTime.now(),
        Batch_Job_Id__c = jobId
    ));
}

// --- Apply user updates ---
try {
    update usersToUpdate;
    System.debug('SUCCESS: Downgraded ' + usersToUpdate.size() + ' users to Login license');
} catch (Exception e) {
    System.debug('ERROR updating users: ' + e.getMessage());
    throw e;
}

// --- Enqueue log insertion (avoids MIXED_DML_OPERATION) ---
try {
    LicenseChangeLogQueueable q = new LicenseChangeLogQueueable(logs);
    System.enqueueJob(q);
    System.debug('Change logs queued for insertion (' + logs.size() + ' records)');
} catch (Exception e) {
    System.debug('WARNING: Could not queue change logs: ' + e.getMessage());
}

// --- Verification query ---
AggregateResult[] after = [
    SELECT Profile.UserLicense.Name lic, COUNT(Id) cnt
    FROM User
    WHERE IsActive = true
    AND Profile.UserLicense.Name IN ('Customer Community Plus', 'Customer Community Plus Login')
    GROUP BY Profile.UserLicense.Name
];
System.debug('--- License counts after downgrade ---');
for (AggregateResult r : after) {
    System.debug(r.get('lic') + ': ' + r.get('cnt'));
}
System.debug('=== Done ===');

// --- Sort helper ---
class AscLoginCountComparator implements Comparator<User> {
    private Map<Id, Integer> counts;
    AscLoginCountComparator(Map<Id, Integer> counts) { this.counts = counts; }
    public Integer compare(User a, User b) {
        Integer ca = counts.containsKey(a.Id) ? counts.get(a.Id) : 0;
        Integer cb = counts.containsKey(b.Id) ? counts.get(b.Id) : 0;
        return ca < cb ? -1 : (ca > cb ? 1 : 0);
    }
}
