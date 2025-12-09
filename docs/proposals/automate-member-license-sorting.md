# Automating Member License Sorting

**Status**: Proposal  
**Created**: 2025-12-08  
**Author**: Jason Adams  
**Related Issue**: #[TBD]

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

- **475 Premium licenses available** (target: reduce to 450 assigned)
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

2. **LicenseShuffleBatch** (`Database.Batchable`)
   - Queries all active Community users
   - Counts logins from `LoginHistory` (past 365 days)
   - Identifies candidates for upgrade/downgrade
   - Updates licenses and profiles
   - Creates audit logs

3. **License_Change_Log__c** (Custom Object)
   - Tracks all license changes
   - Stores: User, old/new license, old/new profile, login count, reason, timestamp

### Flow Diagram

![License Sorting Flow Diagram](automate-member-license-sorting-flow.svg)

## Implementation Details

### License Shuffling Algorithm

1. **Identify Protected Users**:
   - Profile = `SM Community Plus Chair`
   - CreatedDate >= LAST_N_DAYS:90

2. **Calculate Login Counts**:
   - Query `LoginHistory` for each user
   - Filter: `LoginTime >= LAST_N_DAYS:365`
   - Count distinct logins per user

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
- Reason for change
- Timestamp
- Batch job ID

## Expected Outcomes

### Benefits

- **Cost Optimization**: Reduce Premium license usage from 475 to 450, saving ~$225–$250/year
- **Automated Management**: Eliminate manual license assignment overhead
- **Proactive Optimization**: Automatic rebalancing when usage patterns change
- **Audit Trail**: Complete logging of all license changes for compliance

### Metrics

- Premium licenses reduced from 475 to 450 (target)
- Manual license management time reduced to near zero
- License changes logged 100% of the time

## Risks and Considerations

### Technical Risks

- **Governor Limits**: LoginHistory queries are expensive; batch size must be carefully tuned (50-100 users per batch)
- **Query Performance**: Large LoginHistory tables may impact batch execution time
- **Error Handling**: Users with validation rules or required fields may fail to update

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
- [ ] Create `License_Change_Log__c` custom object and fields
- [ ] Create `LicenseMonitorScheduler` class
- [ ] Create `LicenseShuffleBatch` class skeleton

### Phase 2: Core Logic
- [ ] Implement LoginHistory query logic
- [ ] Implement license shuffling algorithm
- [ ] Implement logging functionality

### Phase 3: Testing
- [ ] Create comprehensive test class
- [ ] Test all scenarios (upgrade, downgrade, protected users)
- [ ] Verify governor limit handling

### Phase 4: Deployment
- [ ] Deploy to sandbox for testing
- [ ] Schedule `LicenseMonitorScheduler` to run daily
- [ ] Monitor initial runs and adjust thresholds if needed

### Phase 5: Documentation
- [ ] Update automation documentation
- [ ] Create admin guide for monitoring
- [ ] Document troubleshooting procedures

## Future Enhancements

- **Custom Metadata**: Configurable thresholds (475 trigger, 450 target, 4/20 login thresholds)
- **Email Notifications**: Alert admins when license shuffling occurs
- **Dashboard/Reports**: Visualize license usage trends
- **Manual Trigger**: Option to run optimization immediately
- **Predictive Analytics**: Forecast license needs based on usage trends

## References

- [Salesforce LoginHistory Object Documentation](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_loginhistory.htm)
- [Salesforce Batch Apex Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- Internal notes from conversation with Matt Jeffries

## Approval

- [ ] Tech Team Review
- [ ] Stakeholder Approval
- [ ] Implementation Approved

