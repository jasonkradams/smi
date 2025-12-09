// Script to check License_Change_Log__c records and their field values
// Run this in Anonymous Apex to see what data is actually in the records

System.debug('========================================');
System.debug('Checking License_Change_Log__c records...');
System.debug('========================================');

List<License_Change_Log__c> logs = [
    SELECT Id, Name, User__c, User__r.Name, User__r.Username,
           Old_License__c, New_License__c,
           Old_Profile__c, New_Profile__c,
           Login_Count__c, Reason__c,
           Changed_At__c, Batch_Job_Id__c,
           CreatedDate
    FROM License_Change_Log__c
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('Found ' + logs.size() + ' records');
System.debug('');

if (logs.isEmpty()) {
    System.debug('No License_Change_Log__c records found.');
} else {
    for (License_Change_Log__c log : logs) {
        System.debug('Record: ' + log.Name + ' (ID: ' + log.Id + ')');
        System.debug('  User: ' + (log.User__c != null ? log.User__r.Name + ' (' + log.User__r.Username + ')' : 'null'));
        System.debug('  Old License: ' + log.Old_License__c);
        System.debug('  New License: ' + log.New_License__c);
        System.debug('  Old Profile: ' + log.Old_Profile__c);
        System.debug('  New Profile: ' + log.New_Profile__c);
        System.debug('  Login Count: ' + log.Login_Count__c);
        System.debug('  Reason: ' + log.Reason__c);
        System.debug('  Changed At: ' + log.Changed_At__c);
        System.debug('  Batch Job ID: ' + log.Batch_Job_Id__c);
        System.debug('  Created: ' + log.CreatedDate);
        System.debug('');
    }
}

System.debug('========================================');
System.debug('If fields show as null, the records may have been created');
System.debug('before the fields were deployed, or field-level security');
System.debug('may be restricting access.');
System.debug('========================================');

