// Script to manually run LicenseShuffleBatch
// This will trigger the license shuffling batch job directly
// Run this in Anonymous Apex in the Developer Console

System.debug('========================================');
System.debug('Manually triggering LicenseShuffleBatch...');
System.debug('========================================');

// Direct execution of LicenseShuffleBatch
LicenseShuffleBatch batch = new LicenseShuffleBatch();
Id jobId = Database.executeBatch(batch, 50);
System.debug('SUCCESS: Batch job queued with ID: ' + jobId);
System.debug('');
System.debug('To check batch job status, run:');
System.debug('SELECT Id, Status, JobType, NumberOfErrors, JobItemsProcessed, TotalJobItems');
System.debug('FROM AsyncApexJob');
System.debug('WHERE Id = \'' + jobId + '\'');

System.debug('========================================');
System.debug('Note: License shuffling normally runs daily via LoginHistorySyncBatch');
System.debug('This script is for manual testing/execution only.');
System.debug('========================================');

