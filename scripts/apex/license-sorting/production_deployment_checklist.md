# Production Deployment Checklist

This checklist covers all steps needed to deploy the automated license sorting system to production.

## Pre-Deployment Verification

- [x] All test classes pass with >75% coverage
- [x] All components deployed to staging and tested
- [x] Initial data migration completed in staging
- [x] FLS permissions granted in staging
- [x] Verify no errors in staging runs

## Deployment Steps

### 1. Deploy All Components to Production

```bash
# Deploy custom objects and fields
sf project deploy start \
    --source-dir force-app/main/default/objects/License_Change_Log__c \
    --source-dir force-app/main/default/objects/Fiscal_Year_Login_History__c \
    --target-org production \
    --ignore-warnings

# Deploy all Apex classes and tests
sf project deploy start \
    --source-dir force-app/main/default/classes/LicenseShuffleBatch.cls \
    --source-dir force-app/main/default/classes/LicenseShuffleBatchTest.cls \
    --source-dir force-app/main/default/classes/LicenseChangeLogQueueable.cls \
    --source-dir force-app/main/default/classes/LicenseChangeLogQueueableTest.cls \
    --source-dir force-app/main/default/classes/LoginHistorySyncBatch.cls \
    --source-dir force-app/main/default/classes/LoginHistorySyncBatchTest.cls \
    --source-dir force-app/main/default/classes/LoginHistorySyncScheduler.cls \
    --source-dir force-app/main/default/classes/LoginHistorySyncSchedulerTest.cls \
    --source-dir force-app/main/default/classes/LoginHistoryMigrationBatch.cls \
    --source-dir force-app/main/default/classes/LoginHistoryMigrationBatchTest.cls \
    --source-dir force-app/main/default/classes/LoginHistoryCleanupBatch.cls \
    --source-dir force-app/main/default/classes/LoginHistoryCleanupBatchTest.cls \
    --source-dir force-app/main/default/classes/LoginHistoryCleanupScheduler.cls \
    --source-dir force-app/main/default/classes/LoginHistoryCleanupSchedulerTest.cls \
    --target-org production \
    --test-level RunSpecifiedTests \
    --tests LicenseShuffleBatchTest \
    --tests LicenseChangeLogQueueableTest \
    --tests LoginHistorySyncBatchTest \
    --tests LoginHistorySyncSchedulerTest \
    --tests LoginHistoryMigrationBatchTest \
    --tests LoginHistoryCleanupBatchTest \
    --tests LoginHistoryCleanupSchedulerTest \
    --ignore-warnings
```

### 2. Grant Field-Level Security

Run the FLS grant script in Anonymous Apex:

```bash
sf apex run --file scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex --target-org production
```

Or execute in Developer Console:
- Setup > Developer Console > Debug > Open Execute Anonymous Window
- Copy/paste contents of `scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex`
- Execute

**Expected Result**: All Fiscal_Year_Login_History__c fields should have Read/Edit access for System Administrator profile.

### 3. Initial Data Migration ⚠️ CRITICAL

**IMPORTANT**: This step MUST be completed before running LicenseShuffleBatch. If skipped, all login counts will be 0.

Run the initial migration to backfill last 6 months of LoginHistory data:

```bash
sf apex run --file scripts/apex/license-sorting/migrate_login_history_initial.apex --target-org production
```

Or execute in Developer Console:
- Copy/paste contents of `scripts/apex/license-sorting/migrate_login_history_initial.apex`
- Execute

**Expected Result**: Batch job submitted. Monitor in Setup > Apex Jobs.

**Verification**: After completion, verify records exist:
```sql
SELECT COUNT() FROM Fiscal_Year_Login_History__c
```

**Expected Count**: Should be > 0. If 0, check:
- Are there LoginHistory records in the org?
- Did the batch complete successfully?
- Check debug logs for errors

**Note**: LoginHistorySyncBatch only syncs the last 2 days. The initial migration is required to populate historical data.

### 4. Schedule Daily Sync Job

**IMPORTANT**: Only schedule this AFTER the initial migration (step 3) has completed and verified.

Schedule LoginHistorySyncScheduler to run daily:

```bash
sf apex run --file scripts/apex/license-sorting/schedule_daily_sync.apex --target-org production
```

Or execute in Developer Console:
- Copy/paste contents of `scripts/apex/license-sorting/schedule_daily_sync.apex`
- Execute

**Expected Result**: Job scheduled to run daily at 2:00 AM.

**Verification**: 
```sql
SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State
FROM CronTrigger
WHERE CronJobDetail.Name = 'Login History Sync - Daily'
```

**Note**: The daily sync will maintain Fiscal_Year_Login_History__c going forward, but it only syncs the last 2 days. The initial migration is required for historical data.

### 5. Schedule Annual Cleanup Job

Schedule LoginHistoryCleanupScheduler to run annually on May 1st:

```bash
sf apex run --file scripts/apex/license-sorting/schedule_annual_cleanup.apex --target-org production
```

Or execute in Developer Console:
- Copy/paste contents of `scripts/apex/license-sorting/schedule_annual_cleanup.apex`
- Execute

**Expected Result**: Job scheduled to run May 1st at 3:00 AM annually.

**Verification**:
```sql
SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State
FROM CronTrigger
WHERE CronJobDetail.Name = 'Login History Cleanup - Annual'
```

## Post-Deployment Verification

### Immediate Verification (right after deployment)

- [x] Verify scheduled jobs exist (and are not duplicated):
  ```sql
  SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State
  FROM CronTrigger
  WHERE CronJobDetail.Name IN (
    'Login History Sync - Daily',
    'Login History Cleanup - Annual'
  )
  ORDER BY CronJobDetail.Name
  ```
  **Expected**:
  - `Login History Sync - Daily` with CronExpression `0 0 2 * * ?` and State `WAITING`
  - `Login History Cleanup - Annual` with CronExpression `0 0 3 1 5 ?` and State `WAITING`

- [x] Verify FLS permissions for System Administrator on `Fiscal_Year_Login_History__c` custom fields:
  ```sql
  SELECT Field, PermissionsRead, PermissionsEdit
  FROM FieldPermissions
  WHERE SobjectType = 'Fiscal_Year_Login_History__c'
  AND ParentId IN (
    SELECT Id
    FROM PermissionSet
    WHERE ProfileId IN (SELECT Id FROM Profile WHERE Name = 'System Administrator')
  )
  ORDER BY Field
  ```
  **Note**: `grant_fls_fiscal_year_login_history.apex` upserts permissions for the `__c` (custom) fields on `Fiscal_Year_Login_History__c`.

- [x] Verify initial migration produced data:
  ```sql
  SELECT COUNT() FROM Fiscal_Year_Login_History__c
  ```
  **Expected**: `> 0`

- [x] Sanity-check that the migrated data spans a real date range:
  ```sql
  SELECT MIN(Login_Time__c), MAX(Login_Time__c)
  FROM Fiscal_Year_Login_History__c
  ```

### First end-to-end run verification (Sync → Shuffle)

- [x] Trigger a run now (recommended; don’t wait for 2:00 AM):
  ```bash
  # Option A: run ONLY the shuffle (requires Fiscal_Year_Login_History__c already populated)
  sf apex run --file scripts/apex/license-sorting/run_license_monitor_manually.apex --target-org production
  ```
  If you want to run the full flow manually (sync recent logins, then shuffle), execute in Anonymous Apex:
  ```apex
  Database.executeBatch(new LoginHistorySyncBatch(), 200);
  // Wait for sync to complete, then:
  Database.executeBatch(new LicenseShuffleBatch(), 50);
  ```

- [x] Confirm the relevant batch jobs ran successfully:
  ```sql
  SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
         CreatedDate, CompletedDate, ApexClass.Name
  FROM AsyncApexJob
  WHERE ApexClass.Name IN (
    'LoginHistoryMigrationBatch',
    'LoginHistorySyncBatch',
    'LicenseShuffleBatch',
    'LoginHistoryCleanupBatch'
  )
  ORDER BY CreatedDate DESC
  LIMIT 20
  ```

- [x] Verify `License_Change_Log__c` records are being created (0 is OK if no changes were needed):
  ```sql
  SELECT COUNT(), Reason__c
  FROM License_Change_Log__c
  WHERE CreatedDate = LAST_N_DAYS:7
  GROUP BY Reason__c
  ORDER BY COUNT() DESC
  ```
  Optional (inspect the most recent 10 records with field values):
  ```bash
  sf apex run --file scripts/apex/license-sorting/check_license_change_logs.apex --target-org production
  ```

- [x] Verify license assignments look reasonable:
  ```sql
  SELECT Profile.UserLicense.Name, COUNT()
  FROM User
  WHERE IsActive = true
  AND Profile.UserLicense.Name IN ('Customer Community Plus', 'Customer Community Plus Login')
  GROUP BY Profile.UserLicense.Name
  ```

## Monitoring

### Daily Monitoring (First Week)

- [ ] Check Apex Jobs daily for errors
- [ ] Verify License_Change_Log__c records are being created
- [ ] Monitor license distribution
- [ ] Check debug logs for any warnings

### Ongoing Monitoring

- [ ] Weekly review of License_Change_Log__c records
- [ ] Monthly verification of license distribution
- [ ] Quarterly review of system performance

## Troubleshooting

### If Jobs Fail

1. Check Apex Jobs for error details
2. Review debug logs for specific errors
3. Verify FLS permissions are correct
4. Check if custom objects are accessible

### If No License Changes Occur

1. Verify users have login history in Fiscal_Year_Login_History__c
2. Check if users meet threshold criteria (>5 logins)
3. Verify protected users are correctly identified
4. Check if max Premium license limit (475) is reached

### Manual Execution

To manually trigger the sync and shuffle:

```bash
sf apex run --file scripts/apex/license-sorting/run_license_monitor_manually.apex --target-org production
```

Or execute in Developer Console:
- Copy/paste contents of `scripts/apex/license-sorting/run_license_monitor_manually.apex`
- Execute

## Rollback Plan

If issues occur, you can:

1. **Abort scheduled jobs**:
   ```sql
   CronTrigger job = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Login History Sync - Daily' LIMIT 1];
   System.abortJob(job.Id);
   ```

2. **Disable via code**: Comment out the executeBatch call in LoginHistorySyncBatch.finish()

3. **Manual license reassignment**: Use standard Salesforce User management

## Notes

- The system is idempotent - safe to run multiple times
- Protected users (Chairs and new users <90 days) always retain Premium
- Maximum 475 Premium licenses will be assigned
- All changes are logged to License_Change_Log__c for auditing

