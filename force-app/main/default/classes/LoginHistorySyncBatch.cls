/**
 * Batch class to sync LoginHistory records to Fiscal_Year_Login_History__c custom object.
 * 
 * Queries LoginHistory records from the last 2 days and upserts them to the custom object
 * using the Login_History_Id__c external ID to prevent duplicates.
 * 
 * After completion, triggers LicenseShuffleBatch to run license optimization.
 */
public class LoginHistorySyncBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Integer totalRecordsProcessed = 0;
    private Integer totalRecordsUpserted = 0;
    private Integer totalErrors = 0;
    
    /**
     * Batch start method - queries LoginHistory records from last 2 days
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('LoginHistorySyncBatch: Starting sync job ' + bc.getJobId());
        
        // Query LoginHistory records from last 2 days to catch any missed records
        DateTime twoDaysAgo = DateTime.now().addDays(-2);
        
        return Database.getQueryLocator([
            SELECT Id, UserId, LoginTime, LoginType, SourceIp, LoginUrl, 
                   Browser, Platform, Status, Application, ClientVersion, 
                   ApiType, ApiVersion, CountryIso
            FROM LoginHistory
            WHERE LoginTime >= :twoDaysAgo
            ORDER BY LoginTime DESC
        ]);
    }
    
    /**
     * Batch execute method - upserts LoginHistory records to custom object
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('LoginHistorySyncBatch: No records to process in this batch');
            return;
        }
        
        List<Fiscal_Year_Login_History__c> recordsToUpsert = new List<Fiscal_Year_Login_History__c>();
        
        for (sObject obj : scope) {
            LoginHistory lh = (LoginHistory)obj;
            totalRecordsProcessed++;
            
            Fiscal_Year_Login_History__c fyRecord = new Fiscal_Year_Login_History__c();
            fyRecord.Login_History_Id__c = String.valueOf(lh.Id);
            fyRecord.User__c = lh.UserId;
            fyRecord.Login_Time__c = lh.LoginTime;
            fyRecord.Login_Type__c = lh.LoginType;
            fyRecord.Source_Ip__c = lh.SourceIp;
            fyRecord.Login_Url__c = lh.LoginUrl;
            fyRecord.Browser__c = lh.Browser;
            fyRecord.Platform__c = lh.Platform;
            fyRecord.Status__c = lh.Status;
            fyRecord.Application__c = lh.Application;
            fyRecord.Client_Version__c = lh.ClientVersion;
            fyRecord.Api_Type__c = lh.ApiType;
            fyRecord.Api_Version__c = lh.ApiVersion;
            fyRecord.Country_Iso__c = lh.CountryIso;
            
            recordsToUpsert.add(fyRecord);
        }
        
        // Upsert using external ID to prevent duplicates
        if (!recordsToUpsert.isEmpty()) {
            try {
                Database.UpsertResult[] results = Database.upsert(
                    recordsToUpsert, 
                    Fiscal_Year_Login_History__c.Login_History_Id__c,
                    false // Allow partial success
                );
                
                Integer successCount = 0;
                for (Database.UpsertResult result : results) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        totalErrors++;
                        System.debug('LoginHistorySyncBatch: Upsert error: ' + result.getErrors());
                    }
                }
                totalRecordsUpserted += successCount;
                System.debug('LoginHistorySyncBatch: Upserted ' + successCount + ' of ' + recordsToUpsert.size() + ' records in this batch');
            } catch (Exception e) {
                totalErrors++;
                System.debug('LoginHistorySyncBatch: Error during upsert: ' + e.getMessage());
                System.debug('LoginHistorySyncBatch: Stack trace: ' + e.getStackTraceString());
            }
        }
    }
    
    /**
     * Batch finish method - logs statistics and triggers LicenseShuffleBatch
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('LoginHistorySyncBatch: Sync job completed');
        System.debug('LoginHistorySyncBatch: Total records processed: ' + totalRecordsProcessed);
        System.debug('LoginHistorySyncBatch: Total records upserted: ' + totalRecordsUpserted);
        System.debug('LoginHistorySyncBatch: Total errors: ' + totalErrors);
        
        // Trigger LicenseShuffleBatch to run license optimization
        // This ensures sync completes before shuffling
        try {
            System.debug('LoginHistorySyncBatch: Triggering LicenseShuffleBatch');
            LicenseShuffleBatch batch = new LicenseShuffleBatch();
            
            // In test context, skip executeBatch to avoid "No more than one executeBatch" error
            if (!Test.isRunningTest()) {
                Database.executeBatch(batch, 50);
                System.debug('LoginHistorySyncBatch: Successfully triggered LicenseShuffleBatch');
            } else {
                System.debug('LoginHistorySyncBatch: Test context - LicenseShuffleBatch instantiated but not executed');
            }
        } catch (Exception e) {
            System.debug('LoginHistorySyncBatch: Error triggering LicenseShuffleBatch: ' + e.getMessage());
            System.debug('LoginHistorySyncBatch: Stack trace: ' + e.getStackTraceString());
        }
    }
}

