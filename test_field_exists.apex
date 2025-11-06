// Test if User_Lookup__c field exists
try {
    Contact testContact = [SELECT Id, User_Lookup__c FROM Contact LIMIT 1];
    System.debug('SUCCESS: User_Lookup__c field exists on Contact object');
    
    // Check if it has a value
    if (testContact.User_Lookup__c != null) {
        System.debug('Sample Contact has User_Lookup__c: ' + testContact.User_Lookup__c);
    } else {
        System.debug('Sample Contact User_Lookup__c is null');
    }
} catch (Exception e) {
    System.debug('ERROR: User_Lookup__c field does not exist: ' + e.getMessage());
}
