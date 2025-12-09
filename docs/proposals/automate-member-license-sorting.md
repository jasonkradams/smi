# Automating Member License Sorting

**Status**: ✅ Implemented  
**Created**: 2025-12-08  
**Implemented**: 2025-12-09  
**Author**: Jason Adams  
**Related Issue**: [#42](https://github.com/jasonkradams/smi/issues/42)

## Problem Statement

The Spokane Mountaineers currently manage two types of Salesforce Community licenses:

- **Customer Community Plus (Premium)**: ~$9–$10 per member per year, unlimited logins
- **Customer Community Plus Login (Login-Based)**: ~$1.50 per member per year, pooled 5,000 total logins per year

Currently, license assignments are managed manually, which leads to:
- Inefficient license usage (Premium licenses assigned to low-usage members)
- Cost optimization opportunities missed
- Manual overhead for administrators
- Risk of exceeding license limits

### Current Constraints

- **500 Premium licenses available** (target: reduce to 450 assigned)
- **Chairs must remain Premium** (Profile: `SM Community Plus Chair`)
- **New users (<90 days old) must remain Premium** (to allow for initial usage patterns)
- **200 Plus Login licenses** included in contract

### Usage Indicators

Based on analysis with Matt Jeffries:
- **Plus Login → Plus**: More than **20** logins per year
- **Plus → Plus Login**: **4 or fewer** logins per year

## Proposed Solution

Automate license optimization through a scheduled batch process that:

1. **Monitors Premium license usage** daily
2. **Triggers optimization** when Premium licenses exceed 475
3. **Downgrades low-usage Premium users** (≤4 logins/year) to Login licenses
4. **Upgrades high-usage Login users** (>20 logins/year) to Premium licenses
5. **Protects critical users** (Chairs and new users)
6. **Logs all changes** for auditing and compliance

## Architecture

### Components

1. **LicenseMonitorScheduler** (`Schedulable`)
    - Runs daily to check Premium license count
    - Triggers batch job when count > 475
    - Located in: `force-app/main/default/classes/LicenseMonitorScheduler.cls`

2. **LicenseShuffleBatch** (`Database.Batchable`, `Database.Stateful`)
    - Queries all active Community users
    - Counts logins from `LoginHistory` (fiscal year or last 365 days based on current month)
    - Identifies candidates for upgrade/downgrade
    - Updates licenses and profiles
    - Accumulates audit logs for later insertion
    - Located in: `force-app/main/default/classes/LicenseShuffleBatch.cls`

3. **LicenseChangeLogQueueable** (`Queueable`)
    - Handles insertion of `License_Change_Log__c` records in a separate transaction
    - Resolves `MIXED_DML_OPERATION` error (cannot mix User updates with custom object inserts)
    - Enqueued from `LicenseShuffleBatch.finish()` method
    - Located in: `force-app/main/default/classes/LicenseChangeLogQueueable.cls`

4. **License_Change_Log__c** (Custom Object)
    - Tracks all license changes
    - Stores: User, old/new license, old/new profile, login count, reason, timestamp, batch job ID
    - Located in: `force-app/main/default/objects/License_Change_Log__c/`

### Flow Diagram

![License Sorting Flow Diagram](automate-member-license-sorting-flow.svg)

## Implementation Details

### License Shuffling Algorithm

1. **Identify Protected Users**:
    - Profile = `SM Community Plus Chair`
    - CreatedDate >= LAST_N_DAYS:90

2. **Calculate Login Counts**:
    - Query `LoginHistory` for each user
    - **Fiscal Year Logic**: 
      - If current month < 4 (Jan-Mar): Use `LAST_N_DAYS:365` (last 365 days)
      - If current month >= 4 (Apr-Dec): Use `THIS_FISCAL_YEAR` (April 1 to current date)
    - Count total logins per user in the relevant period

3. **Identify Candidates**:
    - **Downgrade**: Premium users with ≤4 logins (excluding protected)
    - **Upgrade**: Login users with >20 logins

4. **Calculate Target Premium Users**:
    - Start with all protected Premium users
    - Add Premium users sorted by login count (descending)
    - Target: 450 Premium licenses total

5. **Execute Changes**:
    - Downgrade Premium users not in target list
    - Upgrade Login users with >20 logins (up to available Premium slots)

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

- **Automated Management**: Eliminate manual license assignment overhead
- **Proactive Optimization**: Automatic rebalancing when usage patterns change
- **Audit Trail**: Complete logging of all license changes for compliance

### Metrics

- Premium licenses reduced from 475 to 450 (target)
- Manual license management time reduced to near zero
- License changes logged 100% of the time

## Risks and Considerations

### Technical Risks

- **Governor Limits**: LoginHistory queries are expensive; batch size is set to 50 users per batch to stay within limits
- **Query Performance**: Large LoginHistory tables may impact batch execution time
- **Error Handling**: Users with validation rules or required fields may fail to update (errors are logged but don't stop the batch)
- **MIXED_DML_OPERATION**: Cannot update User (setup object) and insert License_Change_Log__c (non-setup object) in the same transaction
  - **Mitigation**: Log records are inserted via `LicenseChangeLogQueueable` in a separate transaction

### Business Risks

- **User Experience**: License changes may affect user access (mitigated by protecting Chairs and new users)
- **Timing**: Batch runs daily; changes may lag behind actual usage patterns
- **Edge Cases**: Users with exactly 4 or 20 logins may oscillate between licenses

### Mitigation Strategies

- Comprehensive test coverage (>75%)
- Idempotent batch design (safe to run multiple times)
- Detailed error logging
- Manual override capability (future enhancement)

## Implementation Plan

### Phase 1: Foundation
- [x] Create `License_Change_Log__c` custom object and fields
- [x] Create `LicenseMonitorScheduler` class
- [x] Create `LicenseShuffleBatch` class skeleton

### Phase 2: Core Logic
- [x] Implement LoginHistory query logic
- [x] Implement license shuffling algorithm
- [x] Implement logging functionality

### Phase 3: Testing
- [x] Create comprehensive test class
- [x] Test all scenarios (upgrade, downgrade, protected users)
- [x] Verify governor limit handling

### Phase 4: Deployment
- [x] Deploy to staging environment for testing
- [x] Create test data and verify functionality
- [x] Fix MIXED_DML_OPERATION issue with Queueable class
- [x] Verify log record creation for upgrades and downgrades
- [x] Restore threshold to production value (475)
- [ ] Schedule `LicenseMonitorScheduler` to run daily
- [ ] Monitor initial runs and adjust thresholds if needed
- [ ] Deploy to production after testing complete

### Phase 5: Documentation
- [x] Update proposal document with implementation details
- [x] Document Queueable class and MIXED_DML workaround
- [ ] Create admin guide for monitoring
- [ ] Document troubleshooting procedures

## Implementation Notes

### Testing Configuration
- **Threshold**: Set to `475` (production value)
- **Location**: `LicenseMonitorScheduler.TRIGGER_THRESHOLD`
- **Manual Execution**: Use `scripts/apex/run_license_monitor_manually.apex` to trigger manually

### Key Implementation Details
- **Batch Size**: 50 users per chunk (to handle LoginHistory queries efficiently)
- **Stateful Processing**: Uses `Database.Stateful` to track Premium users across chunks
- **Log Insertion**: Logs are accumulated during batch execution and inserted via Queueable after completion
- **Protected Users**: Chairs and users <90 days old are never changed

### Test Classes
- `LicenseShuffleBatchTest.cls`: Comprehensive test coverage for batch logic
- `LicenseMonitorSchedulerTest.cls`: Tests scheduler trigger logic
- `LicenseChangeLogQueueableTest.cls`: Tests Queueable log insertion

## Future Enhancements

- **Custom Metadata**: Configurable thresholds (475 trigger, 450 target, 4/20 login thresholds)
<!-- - **Email Notifications**: Alert admins when license shuffling occurs -->
- **Dashboard/Reports**: Visualize license usage trends
- **Manual Trigger**: Option to run optimization immediately (partially implemented via manual script)
- **Predictive Analytics**: Forecast license needs based on usage trends

## References

- [Salesforce LoginHistory Object Documentation](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_loginhistory.htm)
- [Salesforce Batch Apex Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- Internal notes from conversation with Matt Jeffries

## Approval

- [ ] Tech Team Review
- [ ] Stakeholder Approval
- [ ] Implementation Approved

