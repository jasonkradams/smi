// Check sync status
Integer contactsWithEmail = [
    SELECT COUNT() 
    FROM Contact 
    WHERE Email != NULL
];

Integer contactsSynced = [
    SELECT COUNT() 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c != NULL
];

Integer contactsNeedingSync = [
    SELECT COUNT() 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL
];

System.debug('=== SYNC STATUS ===');
System.debug('Total contacts with Email: ' + contactsWithEmail);
System.debug('Contacts synced (have User lookup): ' + contactsSynced);
System.debug('Contacts needing sync: ' + contactsNeedingSync);
System.debug('Sync completion rate: ' + (contactsWithEmail > 0 ? ((contactsSynced * 100.0 / contactsWithEmail)).setScale(2) + '%' : '0%'));

