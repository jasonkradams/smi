/**
 * Queueable class to insert License Change Log records in a separate transaction.
 * 
 * This is necessary because Salesforce doesn't allow mixing DML operations on
 * setup objects (User) and non-setup objects (License_Change_Log__c) in the
 * same transaction.
 */
public class LicenseChangeLogQueueable implements Queueable {
    
    private List<License_Change_Log__c> logsToInsert;
    
    public LicenseChangeLogQueueable(List<License_Change_Log__c> logs) {
        this.logsToInsert = logs != null ? logs : new List<License_Change_Log__c>();
    }
    
    public void execute(QueueableContext context) {
        if (logsToInsert.isEmpty()) {
            System.debug('LicenseChangeLogQueueable: No logs to insert');
            return;
        }
        
        try {
            System.debug('LicenseChangeLogQueueable: Inserting ' + logsToInsert.size() + ' change log records');
            insert logsToInsert;
            System.debug('LicenseChangeLogQueueable: Successfully created ' + logsToInsert.size() + ' change log records');
        } catch (Exception e) {
            System.debug('LicenseChangeLogQueueable: Error creating change logs: ' + e.getMessage());
            System.debug('LicenseChangeLogQueueable: Stack trace: ' + e.getStackTraceString());
            // Log each failed record for debugging
            for (License_Change_Log__c log : logsToInsert) {
                System.debug('  - Failed log: User=' + log.User__c + ', Old=' + log.Old_License__c + ', New=' + log.New_License__c);
            }
            // Re-throw to allow retry mechanism if needed
            throw e;
        }
    }
}

