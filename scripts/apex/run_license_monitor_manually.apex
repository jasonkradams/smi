// Script to manually run the LicenseMonitorScheduler
// This will check the Premium license count and trigger the batch if needed
// Run this in Anonymous Apex in the Developer Console

System.debug('========================================');
System.debug('Running LicenseMonitorScheduler manually...');
System.debug('========================================');

// Option 1: Direct execution (simpler, bypasses scheduler)
// Query Premium license count
Integer premiumLicenseCount = [
    SELECT COUNT()
    FROM User
    WHERE IsActive = true
    AND Profile.UserLicense.Name = 'Customer Community Plus'
];

System.debug('Premium license count: ' + premiumLicenseCount);
System.debug('Threshold: 475');

if (premiumLicenseCount > 475) {
    System.debug('Premium licenses exceed threshold, triggering batch job...');
    LicenseShuffleBatch batch = new LicenseShuffleBatch();
    Id jobId = Database.executeBatch(batch, 50);
    System.debug('SUCCESS: Batch job queued with ID: ' + jobId);
    System.debug('');
    System.debug('To check batch job status, run:');
    System.debug('SELECT Id, Status, JobType, NumberOfErrors, JobItemsProcessed, TotalJobItems');
    System.debug('FROM AsyncApexJob');
    System.debug('WHERE Id = \'' + jobId + '\'');
} else {
    System.debug('Premium license count is within threshold, no batch needed.');
}

System.debug('========================================');

// Option 2: Use the scheduler class directly
// If you want to test the actual scheduler class, you can schedule it temporarily:
// System.schedule('Manual License Monitor Run', '0 0 * * * ?', new LicenseMonitorScheduler());
// Then immediately abort it, or just use Option 1 above which does the same thing.

