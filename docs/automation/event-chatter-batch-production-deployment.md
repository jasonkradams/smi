# Event Chatter Batch Posting - Production Deployment Plan

## Overview

This document provides a step-by-step plan for deploying the Event Chatter Batch Posting feature to the production Salesforce org (`smi`).

**Feature Summary**: Automated batch job that posts approved events to their respective activity group Chatter groups every 60 minutes (hourly).

---

## Pre-Deployment Checklist

### 1. Verify Prerequisites

- [x] Admin access to production org (`smi`)
- [x] Salesforce CLI configured with production org authentication
- [x] All code changes committed to git
- [ ] All tests passing in staging
- [x] Feature tested and verified in staging sandbox

### 2. Review Changes to Deploy

**New Apex Classes**:
- `EventChatterBatchPoster.cls` - Batch class for processing events
- `EventChatterBatchPosterTest.cls` - Test class (75%+ coverage)
- `EventChatterBatchScheduler.cls` - Utility for scheduling (optional)

**Modified Apex Classes**:
- `EventChatterPostHelper.cls` - Updated with batch posting methods
- `EventChatterPostHelperTest.cls` - Updated test class

**New Flow**:
- `Add_Chatter_Service_To_New_Groups.flow-meta.xml` - Auto-adds Event Bot to new Chatter groups

**New Custom Field**:
- `Event_Registration__c.Chatter_Posted__c` - Checkbox to track posted events

**Scripts** (for post-deployment setup):
- `scripts/apex/mark_all_events_as_posted.apex` - Mark existing events as posted
- `scripts/apex/schedule_event_chatter_batch.apex` - Schedule the batch job

### 3. Verify Production Org State

Before deploying, verify:
- [ ] No existing scheduled jobs with name "Event Chatter Batch Posting - Hourly"
- [ ] `Event_Registration__c` object exists
- [ ] Activity group Chatter groups exist (Hiking, Climbing, etc.)
- [ ] Event Bot service account exists (if using service account approach)

---

## Deployment Steps

### Step 1: Deploy Custom Field

**File**: `force-app/main/default/objects/Event_Registration__c/fields/Chatter_Posted__c.field-meta.xml`

```bash
sf project deploy start \
    --target-org smi \
    --source-dir force-app/main/default/objects/Event_Registration__c/fields/Chatter_Posted__c.field-meta.xml
```

**Verify**:
- Field appears in Object Manager → Event Registration → Fields & Relationships
- Field label: "Chatter Posted"
- Field type: Checkbox
- Default value: Unchecked

**Time**: ~2 minutes

---

### Step 2: Deploy Apex Classes

**Files**:
- `force-app/main/default/classes/EventChatterBatchPoster.cls`
- `force-app/main/default/classes/EventChatterBatchPoster.cls-meta.xml`
- `force-app/main/default/classes/EventChatterBatchPosterTest.cls`
- `force-app/main/default/classes/EventChatterBatchPosterTest.cls-meta.xml`
- `force-app/main/default/classes/EventChatterPostHelper.cls`
- `force-app/main/default/classes/EventChatterPostHelper.cls-meta.xml`
- `force-app/main/default/classes/EventChatterPostHelperTest.cls`
- `force-app/main/default/classes/EventChatterPostHelperTest.cls-meta.xml`
- `force-app/main/default/classes/EventChatterBatchScheduler.cls` (optional)
- `force-app/main/default/classes/EventChatterBatchScheduler.cls-meta.xml` (optional)

**Deploy with Tests**:

```bash
sf project deploy start \
    --target-org smi \
    --source-dir force-app/main/default/classes \
    --test-level RunSpecifiedTests \
    --tests EventChatterBatchPosterTest \
    --tests EventChatterPostHelperTest
```

**Alternative: Deploy All Classes at Once**:

```bash
sf project deploy start \
    --target-org smi \
    --source-dir force-app/main/default/classes/EventChatterBatchPoster.cls \
    --source-dir force-app/main/default/classes/EventChatterBatchPoster.cls-meta.xml \
    --source-dir force-app/main/default/classes/EventChatterBatchPosterTest.cls \
    --source-dir force-app/main/default/classes/EventChatterBatchPosterTest.cls-meta.xml \
    --source-dir force-app/main/default/classes/EventChatterPostHelper.cls \
    --source-dir force-app/main/default/classes/EventChatterPostHelper.cls-meta.xml \
    --source-dir force-app/main/default/classes/EventChatterPostHelperTest.cls \
    --source-dir force-app/main/default/classes/EventChatterPostHelperTest.cls-meta.xml \
    --test-level RunSpecifiedTests \
    --tests EventChatterBatchPosterTest \
    --tests EventChatterPostHelperTest
```

**Verify**:
- All classes compile successfully
- All tests pass (75%+ coverage)
- No deployment errors

**Time**: ~5-10 minutes

---

### Step 3: Deploy Flow

**File**: `force-app/main/default/flows/Add_Chatter_Service_To_New_Groups.flow-meta.xml`

```bash
sf project deploy start \
    --target-org smi \
    --source-dir force-app/main/default/flows/Add_Chatter_Service_To_New_Groups.flow-meta.xml \
    --target-org smi
```

**Verify**:
- Flow appears in Setup → Flows
- Flow is **Active**
- Flow triggers on `CollaborationGroup` creation

**Time**: ~2 minutes

---

### Step 4: Mark All Existing Events as Posted (CRITICAL)

**Purpose**: Prevent the batch job from posting about events that were approved before this feature was implemented.

**IMPORTANT**: This **MUST** be run BEFORE scheduling the batch job for the first time.

**Script**: `scripts/apex/mark_all_events_as_posted.apex`

**Option A: Using Salesforce CLI**:

```bash
sf apex run --target-org smi -f scripts/apex/mark_all_events_as_posted.apex
```

**Option B: Using Developer Console**:

1. Go to **Setup → Developer Console**
2. **Debug → Open Execute Anonymous Window**
3. Copy and paste contents of `scripts/apex/mark_all_events_as_posted.apex`
4. Check **Open Log** and click **Execute**
5. Review debug logs to confirm all events were updated

**Verify**:
```bash
sf data query --target-org smi \
    --query "SELECT COUNT() FROM Event_Registration__c WHERE Chatter_Posted__c = true"
```

This should return the total count of all `Event_Registration__c` records.

**What This Does**:
- Sets `Chatter_Posted__c = true` on ALL existing `Event_Registration__c` records
- Ensures the batch job only processes NEW events approved after rollout
- Prevents duplicate or unwanted posts about historical events

**Time**: ~2-3 minutes

---

### Step 5: Schedule the Batch Job

**Script**: `scripts/apex/schedule_event_chatter_batch.apex`

**Option A: Using Salesforce CLI**:

```bash
sf apex run --target-org smi -f scripts/apex/schedule_event_chatter_batch.apex
```

**Option B: Using Developer Console**:

1. Go to **Setup → Developer Console**
2. **Debug → Open Execute Anonymous Window**
3. Copy and paste contents of `scripts/apex/schedule_event_chatter_batch.apex`
4. Check **Open Log** and click **Execute**
5. Review debug logs for job ID and next fire time

**Option C: Manual Scheduling**:

1. Go to **Setup → Apex Classes**
2. Find `EventChatterBatchPoster`
3. Click **Schedule Apex**
4. Configure:
   - **Job Name**: `Event Chatter Batch Posting - Hourly`
   - **Frequency**: Hourly (or use cron expression `0 0 * * * ?`)
   - **Start Time**: Top of the hour (e.g., 12:00 AM)
   - **Time Zone**: Pacific Time
5. Click **Save**

**Verify**:
- Job appears in **Setup → Scheduled Jobs**
- Job name: "Event Chatter Batch Posting - Hourly"
- Next fire time: Top of the next hour
- Status: Waiting

**Cron Expression**: `0 0 * * * ?` (Every hour at minute 0, second 0)

**Time**: ~2 minutes

---

### Step 6: (Optional) Verify Event Bot Service Account

If you're using a service account to post to Chatter:

**Verify Event Bot Exists**:
```bash
sf data query --target-org smi \
    --query "SELECT Id, Username, IsActive FROM User WHERE Username = 'eventbot@spokanemountaineers.org.smi'"
```

**Verify Event Bot is in Chatter Groups**:
- Check that Event Bot is a member of all activity group Chatter groups
- If not, run `scripts/apex/add_chatter_service_to_all_groups.apex` (if it exists)

**Note**: In production, the batch job will run as the user who scheduled it. If you want it to run as the Event Bot service account, you'll need to schedule it as that user (which may require logging in as that user or using a different approach).

**Time**: ~2-3 minutes

---

## Post-Deployment Verification

### 1. Verify Deployment

- [ ] All classes deployed successfully
- [ ] All tests passed
- [ ] Flow is active
- [ ] Custom field exists
- [ ] Scheduled job is active

### 2. Test the Batch Job

**Create a Test Event**:

1. Create a new `Event_Registration__c` record:
   - Set `Status__c = 'Approved'`
   - Set `Activity_Group__c = 'Hiking'` (or any valid activity group)
   - Verify `Chatter_Posted__c` is unchecked (default)

2. **Run Batch Job Manually**:

```bash
sf apex run --target-org smi -f /dev/stdin << 'EOF'
Database.executeBatch(new EventChatterBatchPoster(), 200);
EOF
```

**Or in Developer Console**:
```apex
Database.executeBatch(new EventChatterBatchPoster(), 200);
```

3. **Verify Results**:
   - Check **Setup → Apex Jobs** for job status (should complete successfully)
   - Check the Hiking Chatter group for new post
   - Verify `Chatter_Posted__c = true` on the test event
   - Verify post format matches expected format (single event format)

4. **Test Duplicate Prevention**:
   - Modify the test event (change Location, etc.)
   - Run batch job again
   - Verify event is NOT reprocessed (no duplicate post)
   - Verify `Chatter_Posted__c` remains `true`

**Time**: ~5-10 minutes

### 3. Monitor First Scheduled Run

- [ ] Check **Setup → Scheduled Jobs** after first run (within the next hour)
- [ ] Review **Setup → Apex Jobs** for any errors
- [ ] Verify posts appear in Chatter groups
- [ ] Check debug logs if issues occur

---

## Rollback Plan

If issues occur after deployment:

### Immediate Actions

1. **Stop the Scheduled Job**:
   ```bash
   sf apex run --target-org smi -f /dev/stdin << 'EOF'
   List<CronTrigger> jobs = [
       SELECT Id FROM CronTrigger 
       WHERE CronJobDetail.Name = 'Event Chatter Batch Posting - Hourly'
   ];
   for (CronTrigger ct : jobs) {
       System.abortJob(ct.Id);
   }
   EOF
   ```
   
   Or manually:
   - Go to **Setup → Scheduled Jobs**
   - Find "Event Chatter Batch Posting - Hourly"
   - Click **Abort**

2. **Deactivate Flow** (if causing issues):
   - Go to **Setup → Flows**
   - Find `Add Chatter Service To New Groups`
   - Click **Deactivate**

### Code Rollback (If Needed)

If you need to revert code changes:

1. **Revert Apex Classes**:
   - Deploy previous version from git history
   - Or comment out batch job scheduling

2. **Remove Custom Field** (if needed):
   ```bash
   sf project delete source \
       --target-org smi \
       --source-dir force-app/main/default/objects/Event_Registration__c/fields/Chatter_Posted__c.field-meta.xml
   ```
   **Warning**: This is destructive and will remove the field and all data.

### Re-enable Old Flow (If Needed)

If the old `Notify_Subscribers_New_Event` flow was deactivated and needs to be re-enabled:
- Go to **Setup → Flows**
- Find `Notify Subscribers New Event`
- Click **Activate**

---

## Deployment Timeline

**Estimated Total Time**: ~20-30 minutes

- Step 1 (Field): ~2 minutes
- Step 2 (Classes): ~5-10 minutes
- Step 3 (Flow): ~2 minutes
- Step 4 (Mark Events): ~2-3 minutes
- Step 5 (Schedule): ~2 minutes
- Step 6 (Service Account): ~2-3 minutes (optional)
- Verification: ~5-10 minutes

---

## Quick Reference

**Required Components**:
- Custom Field: `Event_Registration__c.Chatter_Posted__c` (Checkbox)
- Apex Classes: `EventChatterBatchPoster`, `EventChatterPostHelper` (updated)
- Flow: `Add_Chatter_Service_To_New_Groups`
- Scheduled Job: "Event Chatter Batch Posting - Hourly" (runs every 60 minutes)

**Query Logic**: 
```sql
Status__c = 'Approved' 
AND Activity_Group__c != null 
AND Chatter_Posted__c != true
```

**Cron Expression**: `0 0 * * * ?` (Every hour at minute 0, second 0)

**Batch Size**: 200 records per batch execution

---

## Post-Deployment Monitoring

### First Week

- Monitor **Setup → Scheduled Jobs** daily
- Check **Setup → Apex Jobs** for any failures
- Verify posts appear in Chatter groups
- Review any user feedback

### Ongoing

- Weekly check of scheduled job status
- Monthly review of batch job performance
- Monitor for any errors in debug logs

---

## Support & Troubleshooting

**Common Issues**:

1. **Batch job fails with "INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"**:
   - Verify Event Bot service account has proper permissions
   - Check that Event Bot is a member of all Chatter groups

2. **Events not being posted**:
   - Verify `Chatter_Posted__c` field exists and is accessible
   - Check that events have `Status__c = 'Approved'` and `Activity_Group__c != null`
   - Review batch job debug logs

3. **Duplicate posts**:
   - Verify `Chatter_Posted__c` is being set to `true` after posting
   - Check that Step 4 (mark all existing events) was run before scheduling

4. **Scheduled job not running**:
   - Verify job is active in **Setup → Scheduled Jobs**
   - Check next fire time is correct
   - Review org's time zone settings

---

## Notes

- The batch job runs every 60 minutes (hourly) at the top of each hour
- Events are only posted once (tracked by `Chatter_Posted__c`)
- The job processes events in batches of 200
- Posts are made to activity group Chatter groups (Hiking, Climbing, etc.)
- The job runs as the user who scheduled it (or as specified in the scheduler)

---

**Last Updated**: Based on staging deployment on 2025-11-29
**Deployment Target**: Production org `smi`
**Feature Status**: Ready for Production

