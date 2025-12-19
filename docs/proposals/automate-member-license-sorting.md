# Automating Member License Sorting

**Status**: Ready for Deployment  
**Created**: 2025-12-08  
**Author**: Jason Adams  
**Related Issue**: [#42](https://github.com/jasonkradams/smi/issues/42)

## Problem Statement

The Spokane Mountaineers manage two types of Salesforce Community licenses:

- **Customer Community Plus (Premium)**: ~$9–$10 per member per year, unlimited logins
- **Customer Community Plus Login (Login-Based)**: ~$1.50 per member per year, pooled 5,000 total logins per year

The system automatically optimizes license assignments to address:

- Inefficient license usage (Premium licenses assigned to low-usage members)
- Cost optimization opportunities
- Manual administrative overhead
- Risk of exceeding license limits

### System Constraints

- **505 Premium licenses available** (maximum: 475 assigned)
- **Chairs must remain Premium** (Profile: `SM Community Plus Chair`)
- **New users (<90 days old) must remain Premium** (to allow for initial usage patterns)
- **200 Plus Login licenses** included in contract

### Usage Indicators

- **Plus Login → Plus**: More than **5** logins per year
- **Plus → Plus Login**: **5 or fewer** logins per year
- **Maximum Premium licenses**: 475 (if more than 475 users qualify, top 475 by login count get Premium)

## Solution

Automate license optimization through a scheduled batch process that:

1. **Runs daily** to optimize license assignments
2. **Assigns Premium licenses** to users with >5 logins, up to a maximum of 475 Premium licenses
3. **Protects critical users** (Chairs and new users <90 days) - they always get Premium
4. **Prioritizes by login count** - if more than 475 users qualify, top 475 by login count get Premium
5. **Tracks full fiscal year** login history via custom object (LoginHistory API only provides 6 months)
6. **Logs all changes** for auditing and compliance

## Architecture

### Components

1. **Fiscal_Year_Login_History\_\_c** (Custom Object)
    - Mirrors LoginHistory records to track full fiscal year (Feb 1 - Jan 31) login activity
    - Required because LoginHistory API only provides 6 months of data
    - Fields mirror LoginHistory structure with external ID on `Login_History_Id__c` to prevent duplicates
    - Located in: `force-app/main/default/objects/Fiscal_Year_Login_History__c/`

2. **LoginHistorySyncBatch** (`Database.Batchable`, `Database.Stateful`)
    - Runs daily to sync LoginHistory records to Fiscal_Year_Login_History\_\_c
    - Queries LoginHistory from last 2 days and upserts to custom object
    - Triggers LicenseShuffleBatch in finish() method to ensure sync completes before shuffling
    - Located in: `force-app/main/default/classes/LoginHistorySyncBatch.cls`

3. **LoginHistorySyncScheduler** (`Schedulable`)
    - Schedules LoginHistorySyncBatch to run daily (e.g., 2:00 AM)
    - Located in: `force-app/main/default/classes/LoginHistorySyncScheduler.cls`

4. **LoginHistoryCleanupBatch** (`Database.Batchable`)
    - Runs annually on May 1st to delete records before February 1st of previous fiscal year
    - Keeps exactly one full fiscal year of data (Feb 1 - Jan 31)
    - Located in: `force-app/main/default/classes/LoginHistoryCleanupBatch.cls`

5. **LoginHistoryCleanupScheduler** (`Schedulable`)
    - Schedules LoginHistoryCleanupBatch to run annually on May 1st
    - Located in: `force-app/main/default/classes/LoginHistoryCleanupScheduler.cls`

6. **LicenseShuffleBatch** (`Database.Batchable`, `Database.Stateful`)
    - Queries all active Community users
    - Counts logins from `Fiscal_Year_Login_History__c` (fiscal year: Feb 1 - Jan 31)
    - Assigns Premium licenses to users with >5 logins, up to maximum of 475
    - Updates licenses and profiles
    - Accumulates audit logs for later insertion
    - Located in: `force-app/main/default/classes/LicenseShuffleBatch.cls`

7. **LicenseChangeLogQueueable** (`Queueable`)
    - Handles insertion of `License_Change_Log__c` records in a separate transaction
    - Resolves `MIXED_DML_OPERATION` error (cannot mix User updates with custom object inserts)
    - Enqueued from `LicenseShuffleBatch.finish()` method
    - Located in: `force-app/main/default/classes/LicenseChangeLogQueueable.cls`

8. **License_Change_Log\_\_c** (Custom Object)
    - Tracks all license changes
    - Stores: User, old/new license, old/new profile, login count, reason, timestamp, batch job ID
    - Located in: `force-app/main/default/objects/License_Change_Log__c/`

9. **LoginHistoryMigrationBatch** (`Database.Batchable`, `Database.Stateful`)
    - One-time batch class for initial data migration
    - Backfills `Fiscal_Year_Login_History__c` with existing LoginHistory records (last 6 months)
    - Used for initial setup before daily sync process begins
    - Located in: `force-app/main/default/classes/LoginHistoryMigrationBatch.cls`

10. **Field-Level Security Script** (`grant_fls_fiscal_year_login_history.apex`)
    - Anonymous Apex script to grant FLS access to System Administrator profile
    - Programmatically sets read/edit permissions for all Fiscal_Year_Login_History\_\_c fields
    - Must be run after deploying the custom object (foundation step)
    - Located in: `scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex`

### Flow Diagram

![License Sorting Flow Diagram](automate-member-license-sorting-flow.svg)

## Implementation Details

### License Shuffling Algorithm

1. **Identify Protected Users**:
    - Profile = `SM Community Plus Chair`
    - CreatedDate >= LAST_N_DAYS:90

2. **Calculate Login Counts**:
    - Query `Fiscal_Year_Login_History__c` for each user (not LoginHistory - API only provides 6 months)
    - **Fiscal Year Logic** (Fiscal Year: Feb 1 - Jan 31):
        - If current month in {2,3,4} (Feb-Apr): Use `LAST_N_DAYS:365` (last 365 days - first 3 months of FY)
        - If current month >= 5 (May-Dec): Use current fiscal year (Feb 1 of current year to now)
        - If current month == 1 (Jan): Use fiscal year (Feb 1 of previous year to now)
    - Count total logins per user in the relevant period

3. **Identify Qualifying Users**:
    - **Protected users**: Always get Premium (Chairs and new users <90 days)
    - **Qualifying users**: Users with >5 logins qualify for Premium

4. **Calculate Premium License Assignments**:
    - Always include all protected users (they must be Premium)
    - Include all users with >5 logins
    - If total exceeds 475, sort all qualifying users by login count (descending) and take top 475
    - Maximum: 475 Premium licenses total

5. **Execute Changes**:
    - Assign Premium to users in the keep list (protected + top qualifying users up to 475)
    - Assign Login to users not in the keep list (users with ≤5 logins, or qualifying users beyond the 475 limit)

### Profile Mapping

- **Customer Community Plus** → Profile: `SM Community Plus Member`
- **Customer Community Plus Login** → Profile: `SM Community Plus Login`
- **Chairs** → Profile: `SM Community Plus Chair` (always Premium, never changed)

### Logging

All license changes are logged to `License_Change_Log__c` with:

- User reference
- Old and new license types
- Old and new profile names
- Login count at time of change
- Reason for change ("Low usage" or "High usage")
- Timestamp (`Changed_At__c`)
- Batch job ID

**Important**: Due to Salesforce's `MIXED_DML_OPERATION` restriction, log records are inserted via a `Queueable` job that runs after the batch completes. This means:

- User license changes happen immediately
- Log records are created shortly after (typically within seconds)
- If the Queueable job fails, check debug logs for error details

## Expected Outcomes

### Benefits

- **Automated Management**: Eliminates manual license assignment overhead
- **Proactive Optimization**: Automatically rebalances when usage patterns change
- **Audit Trail**: Provides complete logging of all license changes for compliance
- **Full Fiscal Year Tracking**: Maintains complete fiscal year login history (not limited to 6 months like LoginHistory API)

### Metrics

- Premium licenses assigned: Up to 475 (based on users with >5 logins)
- Manual license management time: Near zero (automated daily)
- License changes logged: 100% of all changes
- Login history tracking: Full fiscal year (Feb 1 - Jan 31)

## Risks and Considerations

### Technical Risks

- **Governor Limits**: LoginHistory queries are expensive; batch size is set to 50 users per batch to stay within limits
- **Query Performance**: Large `Fiscal_Year_Login_History__c` tables may impact batch execution time
- **LoginHistory API Limitation**: LoginHistory API only provides 6 months of data
    - **Mitigation**: Custom object `Fiscal_Year_Login_History__c` tracks full fiscal year via daily sync
- **Error Handling**: Users with validation rules or required fields may fail to update (errors are logged but don't stop the batch)
- **MIXED_DML_OPERATION**: Cannot update User (setup object) and insert `License_Change_Log__c` (non-setup object) in the same transaction
    - **Mitigation**: Log records are inserted via `LicenseChangeLogQueueable` in a separate transaction
- **Data Sync Timing**: `LoginHistorySyncBatch` must complete before `LicenseShuffleBatch` runs
    - **Mitigation**: `LicenseShuffleBatch` is triggered from `LoginHistorySyncBatch.finish()` method
- **Field-Level Security**: System Administrators require FLS permissions for `Fiscal_Year_Login_History__c` fields
    - **Mitigation**: FLS grant script (`scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex`) programmatically sets permissions

### Business Risks

- **User Experience**: License changes may affect user access (mitigated by protecting Chairs and new users <90 days)
- **Timing**: Batch runs daily; changes may lag behind actual usage patterns by up to 24 hours
- **Edge Cases**: Users with exactly 5 logins may oscillate between licenses depending on other qualifying users and the 475 Premium license limit

### Mitigation Strategies

- Comprehensive test coverage (>75% for all classes)
- Idempotent batch design (safe to run multiple times)
- Detailed error logging to `License_Change_Log__c` and debug logs
- Protected users (Chairs and new members) always retain Premium licenses
- Manual batch execution available for immediate optimization when needed

## Implementation Plan

### Phase 1: Foundation ✅

- Create `License_Change_Log__c` custom object and fields
- Create `Fiscal_Year_Login_History__c` custom object and fields
- Create `LicenseShuffleBatch` class skeleton
- Create FLS grant script for field-level security setup

### Phase 2: Core Logic ✅

- Implement fiscal year login counting logic using `Fiscal_Year_Login_History__c`
- Implement license shuffling algorithm (>5 logins, max 475 Premium)
- Implement logging functionality via Queueable class
- Create `LoginHistorySyncBatch` for daily data sync
- Create `LoginHistoryCleanupBatch` for annual data cleanup

### Phase 3: Testing ✅

- Create comprehensive test classes for all components
- Test all scenarios (upgrade, downgrade, protected users, edge cases)
- Verify governor limit handling and batch processing
- Test job chaining (sync batch triggers shuffle batch)

### Phase 4: Deployment & Setup

- [x] Deploy all components to staging environment
- [x] Create Fiscal_Year_Login_History\_\_c custom object and fields
- [x] Create LoginHistorySyncBatch and scheduler
- [x] Create LoginHistoryCleanupBatch and scheduler
- [x] Update LicenseShuffleBatch to use custom object and new logic
- [x] Create LoginHistoryMigrationBatch for initial data backfill
- [x] Create FLS grant script for field-level security setup
- [x] Run FLS grant script to set permissions
- [x] Run initial data migration (LoginHistoryMigrationBatch) to backfill last 6 months
- [ ] Schedule `LoginHistorySyncScheduler` to run daily
- [ ] Schedule `LoginHistoryCleanupScheduler` to run annually on May 1st
- [ ] Monitor initial runs and verify functionality
- [ ] Deploy to production after testing complete

### Phase 5: Documentation

- [x] Document system architecture and components
- [x] Document Queueable class and MIXED_DML workaround
- [x] Document setup scripts and deployment steps
- [ ] Create admin guide for monitoring
- [ ] Document troubleshooting procedures

## Implementation Notes

### Testing Configuration

- **Max Premium Licenses**: 475
- **Login Threshold**: >5 logins qualify for Premium
- **Fiscal Year**: Feb 1 - Jan 31
- **Manual Execution**: Can trigger LoginHistorySyncBatch or LicenseShuffleBatch directly

### Key Implementation Details

- **Batch Size**: 50 users per chunk for LicenseShuffleBatch, 200 for LoginHistorySyncBatch and LoginHistoryMigrationBatch
- **Stateful Processing**: Uses `Database.Stateful` to track Premium users across chunks
- **Log Insertion**: Logs are accumulated during batch execution and inserted via Queueable after completion
- **Protected Users**: Chairs and users <90 days old always get Premium licenses
- **Daily Sync**: LoginHistorySyncBatch runs daily to sync LoginHistory to custom object
- **Annual Cleanup**: LoginHistoryCleanupBatch runs May 1st to delete records before previous fiscal year
- **Job Chaining**: LoginHistorySyncBatch triggers LicenseShuffleBatch in finish() method
- **Field-Level Security**: System Administrator profile requires FLS permissions for Fiscal_Year_Login_History\_\_c fields (granted via script)
- **Initial Migration**: LoginHistoryMigrationBatch provides one-time backfill of last 6 months of LoginHistory data

### Test Classes

- `LicenseShuffleBatchTest.cls`: Comprehensive test coverage for batch logic
- `LicenseChangeLogQueueableTest.cls`: Tests Queueable log insertion
- `LoginHistorySyncBatchTest.cls`: Tests sync batch logic
- `LoginHistorySyncSchedulerTest.cls`: Tests sync scheduler
- `LoginHistoryCleanupBatchTest.cls`: Tests cleanup batch logic
- `LoginHistoryCleanupSchedulerTest.cls`: Tests cleanup scheduler
- `LoginHistoryMigrationBatch`: Includes test methods for initial migration logic

### Setup Scripts

- `scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex`: Grants FLS permissions to System Administrator profile
- `scripts/apex/license-sorting/migrate_login_history_initial.apex`: Executes LoginHistoryMigrationBatch for initial data backfill
- `scripts/apex/license-sorting/README.md`: Documentation for all license sorting scripts

## Deployment Steps

### Initial Setup (One-Time)

1. **Deploy Components**: Deploy all Apex classes, custom objects, and fields to target org
2. **Grant Field-Level Security**: Run `scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex` in Anonymous Apex to grant FLS permissions
3. **Initial Data Migration**: Run `scripts/apex/license-sorting/migrate_login_history_initial.apex` to backfill last 6 months of LoginHistory data
4. **Schedule Daily Sync**: Schedule `LoginHistorySyncScheduler` to run daily (recommended: 2:00 AM)
5. **Schedule Annual Cleanup**: Schedule `LoginHistoryCleanupScheduler` to run annually on May 1st

### Ongoing Operations

- Daily sync automatically maintains `Fiscal_Year_Login_History__c` records
- License shuffling runs automatically after each daily sync completes
- Annual cleanup removes records older than one full fiscal year

## Future Enhancements

- **Custom Metadata**: Configurable thresholds (475 max Premium, 5 login threshold)
- **Dashboard/Reports**: Visualize license usage trends and fiscal year login activity
- **Manual Trigger**: Option to run optimization immediately (available via direct batch execution)
- **Predictive Analytics**: Forecast license needs based on usage trends
- **Data Retention Policy**: Configurable retention period for Fiscal_Year_Login_History\_\_c records

## References

- [Salesforce LoginHistory Object Documentation](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_loginhistory.htm)
- [Salesforce LoginHistory API Limitations](https://help.salesforce.com/s/articleView?id=xcloud.users_login_history.htm&type=5) - Only 6 months of data available via API
- [Salesforce Batch Apex Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- Internal notes from conversation with Matt Jeffries

## Status

System is implemented and ready for production deployment. All components have been deployed to staging and tested. Initial data migration has been completed. System awaits scheduling of daily sync and annual cleanup jobs, followed by production deployment after final testing verification.
