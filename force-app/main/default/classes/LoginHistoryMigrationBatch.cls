/**
 * Batch class to migrate LoginHistory records to Fiscal_Year_Login_History__c custom object.
 * This handles the initial backfill of historical login data.
 */
public class LoginHistoryMigrationBatch implements Database.Batchable<LoginHistory>, Database.Stateful {
    
    private Integer totalProcessed = 0;
    private Integer totalSuccess = 0;
    private Integer totalErrors = 0;
    private List<String> errorMessages = new List<String>();
    
    public Iterable<LoginHistory> start(Database.BatchableContext bc) {
        // Query LoginHistory for the last 6 months (Salesforce API limit)
        Date sixMonthsAgo = Date.today().addMonths(-6);
        DateTime sixMonthsAgoDT = DateTime.newInstance(sixMonthsAgo.year(), sixMonthsAgo.month(), sixMonthsAgo.day());
        
        System.debug('Querying LoginHistory records from: ' + sixMonthsAgoDT);
        
        List<LoginHistory> loginHistoryList = [
            SELECT Id, UserId, LoginTime, LoginType, SourceIp, LoginUrl, 
                   Browser, Platform, Status, Application, ClientVersion,
                   ApiType, ApiVersion, CountryIso
            FROM LoginHistory
            WHERE LoginTime >= :sixMonthsAgoDT
            ORDER BY LoginTime DESC
        ];
        
        System.debug('Found ' + loginHistoryList.size() + ' LoginHistory records to migrate');
        return loginHistoryList;
    }
    
    public void execute(Database.BatchableContext bc, List<LoginHistory> scope) {
        System.debug('Processing batch of ' + scope.size() + ' records');
        
        List<Fiscal_Year_Login_History__c> recordsToUpsert = new List<Fiscal_Year_Login_History__c>();
        
        for (LoginHistory lh : scope) {
            totalProcessed++;
            
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
        
        // Upsert batch using external ID
        if (!recordsToUpsert.isEmpty()) {
            try {
                Database.UpsertResult[] results = Database.upsert(
                    recordsToUpsert, 
                    Fiscal_Year_Login_History__c.Login_History_Id__c,
                    false // Allow partial success
                );
                
                Integer batchSuccess = 0;
                Integer batchErrors = 0;
                
                for (Integer i = 0; i < results.size(); i++) {
                    Database.UpsertResult result = results[i];
                    if (result.isSuccess()) {
                        batchSuccess++;
                        totalSuccess++;
                    } else {
                        batchErrors++;
                        totalErrors++;
                        String errorMsg = 'Record ' + (i + 1) + ': ' + String.join(result.getErrors(), '; ');
                        errorMessages.add(errorMsg);
                        System.debug('ERROR: ' + errorMsg);
                    }
                }
                
                System.debug('Batch complete: ' + batchSuccess + ' succeeded, ' + batchErrors + ' failed');
            } catch (Exception e) {
                System.debug('EXCEPTION during upsert: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                totalErrors += recordsToUpsert.size();
                errorMessages.add('Batch exception: ' + e.getMessage());
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('=== Migration Complete ===');
        System.debug('Total processed: ' + totalProcessed);
        System.debug('Total succeeded: ' + totalSuccess);
        System.debug('Total errors: ' + totalErrors);
        
        if (!errorMessages.isEmpty()) {
            System.debug('Error messages (first 10):');
            Integer count = 0;
            for (String msg : errorMessages) {
                if (count++ < 10) {
                    System.debug('  - ' + msg);
                }
            }
        }
    }
}

