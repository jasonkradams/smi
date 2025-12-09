/**
 * Scheduler class that monitors Premium license usage and triggers
 * the license shuffling batch job when Premium licenses exceed 475.
 * 
 * Runs daily to check license counts and automatically optimize usage.
 */
public class LicenseMonitorScheduler implements Schedulable {
    
    private static final Integer TRIGGER_THRESHOLD = 475;
    
    /**
     * Schedulable execute method - checks Premium license count and triggers batch if needed
     */
    public void execute(SchedulableContext ctx) {
        // Query count of Premium licenses (Customer Community Plus)
        Integer premiumLicenseCount = [
            SELECT COUNT()
            FROM User
            WHERE IsActive = true
            AND Profile.UserLicense.Name = 'Customer Community Plus'
        ];
        
        System.debug('LicenseMonitorScheduler: Premium license count = ' + premiumLicenseCount);
        
        // If count exceeds threshold, execute LicenseShuffleBatch
        if (premiumLicenseCount > TRIGGER_THRESHOLD) {
            System.debug('LicenseMonitorScheduler: Premium licenses exceed threshold (' + TRIGGER_THRESHOLD + '), triggering batch job');
            LicenseShuffleBatch batch = new LicenseShuffleBatch();
            Database.executeBatch(batch, 50); // Small batch size to handle LoginHistory queries
        } else {
            System.debug('LicenseMonitorScheduler: Premium license count (' + premiumLicenseCount + ') is within threshold, no action needed');
        }
    }
}

