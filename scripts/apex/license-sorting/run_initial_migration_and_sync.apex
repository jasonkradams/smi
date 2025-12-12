/**
 * Script to run the initial migration and then the daily sync.
 * 
 * This ensures Fiscal_Year_Login_History__c is populated with historical data
 * before running the license shuffle.
 * 
 * Run this script FIRST before scheduling the daily sync.
 */

System.debug('=== Running Initial Migration and Sync ===');
System.debug('Start time: ' + DateTime.now());

// Step 1: Run initial migration (backfills last 6 months)
System.debug('');
System.debug('Step 1: Running initial migration (LoginHistoryMigrationBatch)...');
try {
    Id migrationJobId = Database.executeBatch(new LoginHistoryMigrationBatch(), 200);
    System.debug('SUCCESS: Initial migration batch queued with ID: ' + migrationJobId);
    System.debug('This will backfill the last 6 months of LoginHistory data.');
    System.debug('');
    System.debug('IMPORTANT: Wait for the migration batch to complete before running LicenseShuffleBatch.');
    System.debug('Monitor progress in Setup > Apex Jobs');
    System.debug('Expected duration: Depends on number of LoginHistory records (typically 5-15 minutes)');
} catch (Exception e) {
    System.debug('ERROR: Failed to start migration batch: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('');
System.debug('=== Next Steps ===');
System.debug('1. Wait for LoginHistoryMigrationBatch to complete');
System.debug('2. Verify records were created: SELECT COUNT() FROM Fiscal_Year_Login_History__c');
System.debug('3. Then run LoginHistorySyncBatch to sync recent records');
System.debug('4. Then run LicenseShuffleBatch to optimize licenses');
System.debug('');
System.debug('To run sync after migration completes:');
System.debug('  Database.executeBatch(new LoginHistorySyncBatch(), 200);');
System.debug('');
System.debug('To run license shuffle after sync completes:');
System.debug('  Database.executeBatch(new LicenseShuffleBatch(), 50);');

