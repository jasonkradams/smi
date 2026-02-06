# Event Chatter Batch Posting - Deployment Steps

## Prerequisites

- Admin access to Salesforce org
- Access to Object Manager and Apex Classes
- Ability to create custom fields

## Deployment Checklist

### 1. Create Required Field

**Field**: `Chatter_Posted__c` on `Event_Registration__c` object

**Steps**:

1. Go to **Setup → Object Manager → Event Registration**
2. Click **Fields & Relationships**
3. Click **New**
4. Select **Checkbox** as the field type
5. Configure:
    - **Field Label**: `Chatter Posted`
    - **Field Name**: `Chatter_Posted__c` (auto-populated)
    - **Default Value**: Unchecked
    - **Description**: "Indicates if this event has been posted to Chatter. Set to true after batch job posts the event."
6. Click **Next** → **Next** → **Save**
7. (Optional) Add field to page layouts if you want visibility

**Time**: ~5 minutes

---

### 2. Deploy Apex Classes

**Files to Deploy**:

- `force-app/main/default/classes/EventChatterBatchPoster.cls`
- `force-app/main/default/classes/EventChatterBatchPoster.cls-meta.xml`
- `force-app/main/default/classes/EventChatterBatchPosterTest.cls`
- `force-app/main/default/classes/EventChatterBatchPosterTest.cls-meta.xml`
- `force-app/main/default/classes/EventChatterPostHelper.cls` (updated with batch methods)
- `force-app/main/default/classes/EventChatterPostHelper.cls-meta.xml`
- `force-app/main/default/classes/EventChatterPostHelperTest.cls` (updated with batch tests)
- `force-app/main/default/classes/EventChatterPostHelperTest.cls-meta.xml`

**Steps**:

1. Deploy via Salesforce CLI:
    ```bash
    sf project deploy start --source-dir force-app/main/default/classes
    ```
2. Or deploy via VS Code Salesforce Extension
3. Or deploy via Change Sets in Setup → Deployment → Outbound Change Sets

**Verify**:

- All classes compile successfully
- Test classes pass (75%+ coverage required)

**Time**: ~5-10 minutes

---

### 3. Mark All Existing Events as Posted (Pre-Rollout)

**Purpose**: Prevent the batch job from posting about events that were approved before this feature was implemented.

**IMPORTANT**: This must be run BEFORE scheduling the batch job for the first time.

**Steps**:

1. Open **Developer Console** (Setup → Developer Console)
2. Go to **Debug → Open Execute Anonymous Window**
3. Copy and paste the contents of `scripts/apex/mark_all_events_as_posted.apex`
4. Check **Open Log** and click **Execute**
5. Review the debug logs to confirm all events were updated
6. Verify the update:
    ```bash
    sf data query --query "SELECT COUNT() FROM Event_Registration__c WHERE Chatter_Posted__c = true" --target-org smi
    ```
    This should return the total count of all Event_Registration\_\_c records

**What This Does**:

- Sets `Chatter_Posted__c = true` on ALL existing Event_Registration\_\_c records
- Ensures the batch job only processes NEW events approved after rollout
- Prevents duplicate or unwanted posts about historical events

**Time**: ~2-3 minutes

---

### 4. Schedule the Batch Job

**Option A: Using Apex Script (Recommended)**

1. Open **Developer Console** or **VS Code Execute Anonymous**
2. Run the script: `scripts/apex/schedule_event_chatter_batch.apex`
3. Verify job was scheduled:
    - Go to **Setup → Scheduled Jobs**
    - Look for "Event Chatter Batch Posting - Daily 5am"
    - Verify next fire time is 5:00 AM Pacific

**Option B: Manual Scheduling**

1. Go to **Setup → Apex Classes**
2. Find `EventChatterBatchPoster`
3. Click **Schedule Apex**
4. Configure:
    - **Job Name**: `Event Chatter Batch Posting - Daily 5am`
    - **Frequency**: Daily
    - **Start Time**: 5:00 AM
    - **Time Zone**: Pacific Time
5. Click **Save**

**Verify**:

- Job appears in **Setup → Scheduled Jobs**
- Next fire time is correct (5:00 AM Pacific)

**Time**: ~2 minutes

---

### 5. Configure Service Account

**Note**: This org uses `sm-client@prolocity.com` as the service account for Chatter posting. Ensure this user:

- Has permissions to read/edit `Event_Registration__c` records
- Is a member of all activity group Chatter groups
- Is added to any new Chatter groups automatically via the `Add_Chatter_Service_To_New_Groups` flow

**Verify Service Account Setup**:

1. Verify service account exists and is active:

    ```bash
    sf data query --target-org smi \
        --query "SELECT Id, Username, IsActive FROM User WHERE Username = 'sm-client@prolocity.com'"
    ```

2. Add service account to all existing Chatter groups:
    - Open **Developer Console** (Setup → Developer Console)
    - Go to **Debug → Open Execute Anonymous Window**
    - Copy and paste the contents of `scripts/apex/add_sm_client_to_all_chatter_groups.apex`
    - Check **Open Log** and click **Execute**
    - Review the debug logs to confirm the service account was added to all groups

3. Deploy Flow for automatic addition to new groups:
    ```bash
    sf project deploy start --target-org smi --source-dir force-app/main/default/flows/Add_Chatter_Service_To_New_Groups.flow-meta.xml
    ```

    - Verify the Flow is **Active** in Setup → Flows
    - The Flow will automatically add the service account to any new Chatter groups created in the future

**Time**: ~5-10 minutes

---

### 6. Verify Deployment

**Test the Batch Job**:

1. Create a test event:
    - Create `Event_Registration__c` record
    - Set `Status__c = 'Approved'`
    - Set `Activity_Group__c = 'Hiking'` (or any valid activity group)
    - Verify `Chatter_Posted__c` is unchecked

2. Run batch job manually:

    ```apex
    Database.executeBatch(new EventChatterBatchPoster(), 200);
    ```

3. Verify results:
    - Check **Setup → Apex Jobs** for job status
    - Check Chatter group for new post
    - Verify `Chatter_Posted__c = true` on the event

4. Test duplicate prevention:
    - Modify the event (change Location, etc.)
    - Run batch job again
    - Verify event is NOT reprocessed (no duplicate post)

**Time**: ~5 minutes

---

## Post-Deployment

### Monitor Initial Runs

- Check **Setup → Scheduled Jobs** after first few runs
- Review **Setup → Apex Jobs** for any errors
- Verify posts appear in Chatter groups
- Check debug logs if issues occur

### Deactivate Old Flow (If Still Active)

If the old `Notify_Subscribers_New_Event` flow is still active:

1. Go to **Setup → Flows**
2. Find `Notify Subscribers New Event`
3. Click **Deactivate** (or it should already be marked Obsolete)

---

## Rollback Plan

If issues occur:

1. **Stop the scheduled job**:
    - Go to **Setup → Scheduled Jobs**
    - Find "Event Chatter Batch Posting - Daily 5am"
    - Click **Abort**

2. **Revert code** (if needed):
    - Deploy previous version of classes
    - Or comment out batch job scheduling

3. **Re-enable old flow** (if needed):
    - Reactivate `Notify_Subscribers_New_Event` flow

---

## Total Deployment Time

- **Minimum**: ~15-20 minutes (field + code + schedule)
- **With Service Account**: ~25-35 minutes
- **With Testing**: ~30-40 minutes

---

## Quick Reference

**Required Field**: `Chatter_Posted__c` (Checkbox) on `Event_Registration__c`

**Apex Classes**:

- `EventChatterBatchPoster` (batch class)
- `EventChatterPostHelper` (helper with batch methods)

**Schedule**: Daily at 5:00 AM Pacific (`0 0 5 * * ?`)

**Query Logic**: `Status__c = 'Approved' AND Activity_Group__c != null AND Chatter_Posted__c != true`
