/**
 * Batch class to clean up old Fiscal_Year_Login_History__c records.
 * 
 * Runs on May 1st to delete records before February 1st of the previous fiscal year.
 * This keeps exactly one full fiscal year of data (Feb 1 - Jan 31).
 */
public class LoginHistoryCleanupBatch implements Database.Batchable<sObject> {
    
    private Integer totalRecordsDeleted = 0;
    private Integer totalErrors = 0;
    
    /**
     * Batch start method - queries records to delete
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('LoginHistoryCleanupBatch: Starting cleanup job ' + bc.getJobId());
        
        // Calculate previous fiscal year start: February 1st of previous year
        Integer currentYear = Date.today().year();
        Date previousFiscalYearStart = Date.newInstance(currentYear - 1, 2, 1);
        DateTime cutoffDateTime = DateTime.newInstance(previousFiscalYearStart, Time.newInstance(0, 0, 0, 0));
        
        System.debug('LoginHistoryCleanupBatch: Deleting records before ' + cutoffDateTime);
        
        // Query records to delete (before Feb 1 of previous fiscal year)
        return Database.getQueryLocator([
            SELECT Id
            FROM Fiscal_Year_Login_History__c
            WHERE Login_Time__c < :cutoffDateTime
        ]);
    }
    
    /**
     * Batch execute method - deletes old records
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('LoginHistoryCleanupBatch: No records to delete in this batch');
            return;
        }
        
        List<Fiscal_Year_Login_History__c> recordsToDelete = new List<Fiscal_Year_Login_History__c>();
        for (sObject obj : scope) {
            recordsToDelete.add((Fiscal_Year_Login_History__c)obj);
        }
        
        try {
            Database.DeleteResult[] results = Database.delete(recordsToDelete, false); // Allow partial success
            
            Integer successCount = 0;
            for (Database.DeleteResult result : results) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    totalErrors++;
                    System.debug('LoginHistoryCleanupBatch: Delete error: ' + result.getErrors());
                }
            }
            totalRecordsDeleted += successCount;
            System.debug('LoginHistoryCleanupBatch: Deleted ' + successCount + ' of ' + recordsToDelete.size() + ' records in this batch');
        } catch (Exception e) {
            totalErrors++;
            System.debug('LoginHistoryCleanupBatch: Error during delete: ' + e.getMessage());
            System.debug('LoginHistoryCleanupBatch: Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Batch finish method - logs statistics
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('LoginHistoryCleanupBatch: Cleanup job completed');
        System.debug('LoginHistoryCleanupBatch: Total records deleted: ' + totalRecordsDeleted);
        System.debug('LoginHistoryCleanupBatch: Total errors: ' + totalErrors);
    }
}

