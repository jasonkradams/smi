/**
 * Initial data migration script to backfill Fiscal_Year_Login_History__c
 * with existing LoginHistory records (last 6 months, due to API limitations).
 * 
 * This script executes the LoginHistoryMigrationBatch batch class.
 * Run this script in Anonymous Apex to start the migration.
 */

System.debug('=== Starting LoginHistory Migration ===');
System.debug('Start time: ' + DateTime.now());

try {
    // Execute the batch job
    Id jobId = Database.executeBatch(new LoginHistoryMigrationBatch(), 200);
    System.debug('Batch job submitted with ID: ' + jobId);
    System.debug('Monitor progress in Setup > Apex Jobs');
} catch (Exception e) {
    System.debug('ERROR: Failed to start migration batch: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('=== Migration Script Complete ===');
