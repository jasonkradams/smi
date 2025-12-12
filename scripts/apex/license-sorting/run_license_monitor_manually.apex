/**
 * Script to manually run LicenseShuffleBatch
 * This will trigger the license shuffling batch job directly
 * 
 * IMPORTANT: Make sure Fiscal_Year_Login_History__c has data before running this!
 * If login counts are showing as 0, run the initial migration first:
 * - scripts/apex/license-sorting/migrate_login_history_initial.apex
 * 
 * Run this in Anonymous Apex in the Developer Console
 */

System.debug('========================================');
System.debug('Manually triggering LicenseShuffleBatch...');
System.debug('========================================');

// Verify Fiscal_Year_Login_History__c has data
Integer recordCount = [SELECT COUNT() FROM Fiscal_Year_Login_History__c];
System.debug('Fiscal_Year_Login_History__c records: ' + recordCount);

if (recordCount == 0) {
    System.debug('');
    System.debug('WARNING: No records found in Fiscal_Year_Login_History__c!');
    System.debug('Login counts will be 0 for all users.');
    System.debug('');
    System.debug('Run the initial migration first:');
    System.debug('  Database.executeBatch(new LoginHistoryMigrationBatch(), 200);');
    System.debug('');
    System.debug('Or run the full setup script:');
    System.debug('  scripts/apex/license-sorting/run_initial_migration_and_sync.apex');
} else {
    System.debug('Records found - proceeding with license shuffle...');
}

// Direct execution of LicenseShuffleBatch
LicenseShuffleBatch batch = new LicenseShuffleBatch();
Id jobId = Database.executeBatch(batch, 50);
System.debug('SUCCESS: Batch job queued with ID: ' + jobId);
System.debug('');
System.debug('To check batch job status, run:');
System.debug('SELECT Id, Status, JobType, NumberOfErrors, JobItemsProcessed, TotalJobItems');
System.debug('FROM AsyncApexJob');
System.debug('WHERE Id = \'' + jobId + '\'');
System.debug('');
System.debug('========================================');
System.debug('Note: License shuffling normally runs daily via LoginHistorySyncBatch');
System.debug('This script is for manual testing/execution only.');
System.debug('========================================');
