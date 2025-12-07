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
   This should return the total count of all Event_Registration__c records

**What This Does**:
- Sets `Chatter_Posted__c = true` on ALL existing Event_Registration__c records
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

### 5. (Optional) Create Event Bot Service Account

**Purpose**: Dedicated account for posting to Chatter groups with minimal permissions and no login access

#### Step 4a: Create Custom Profile

1. Go to **Setup → Users → Profiles**
2. Click **New Profile**
3. Configure:
   - **Profile Name**: `Event Bot`
   - **Based on**: `Chatter Free User` (or `Minimum Access - Salesforce` if Chatter Free User doesn't exist)
4. Click **Save**

#### Step 4b: Configure Profile Permissions

**Object Permissions**:
- **Event Registration** (`Event_Registration__c`):
  - ✅ Read
  - ✅ Edit (needed to update `Chatter_Posted__c` field)

**System Permissions**:
- ✅ **API Enabled** (required for batch jobs)
- ✅ **Chatter Internal User** (enables Chatter access)
- ✅ **Use ConnectApi** (required for ConnectApi.ChatterFeeds)

**User Permissions**:
- ❌ **Login** (disable - prevents user from logging in)
- ✅ **API Enabled** (already enabled in System Permissions above - allows API access for batch jobs)

**Chatter Settings**:
- ✅ **Chatter Enabled**
- ✅ **Post to Groups** (if available)

**Note**: If "Chatter Free User" profile doesn't exist, start with "Minimum Access - Salesforce" and enable only the permissions listed above.

**Important Notes**:
- With **Login** permission disabled, the user cannot access the Salesforce UI
- The user can still execute Apex code (batch jobs, scheduled jobs) when running in that user's context
- This is a security best practice for service accounts - they can perform automated tasks but cannot be used for interactive login

**Verification**: After creating the profile, verify:
- User cannot log in (test by attempting login with the username)
- User can execute Apex (batch jobs will run when configured to run as this user)
- User has access to Chatter groups (verified when adding to groups)

#### Step 4c: Create Service Account User

1. Go to **Setup → Users → Users**
2. Click **New User**
3. Configure:
   - **First Name**: `Event`
   - **Last Name**: `Bot`
   - **Alias**: `eventbot`
   - **Email**: `eventbot@spokanemountaineers.org`
   - **Username**: `eventbot@spokanemountaineers.org.smi` (note: `.smi` suffix is a convention used in this org)
   - **Profile**: `Event Bot` (the custom profile created above)
   - **User License**: Chatter Free
   - **Generate new password**: Unchecked (user won't log in)
4. Click **Save**

#### Step 4d: Add User to Experience Cloud Site and Chatter Groups

The service account needs to be added to the Experience Cloud site first (to access site-specific Chatter groups), then to all Chatter groups.

**Step 4d.1: Add to Experience Cloud Site**

> **Important**: Regular Salesforce users (Chatter Free, Salesforce licenses) **cannot** be added to Experience Cloud sites. Only Community Users can be site members.
>
> **Option A: If Event Bot is a Community User** (recommended for site-specific groups):
> 1. Ensure Event Bot was created from a Contact record with a Community license (e.g., "SM Community Plus Login")
> 2. Open **Developer Console** (Setup → Developer Console)
> 3. Go to **Debug → Open Execute Anonymous Window**
> 4. Copy and paste the contents of `scripts/apex/add_event_bot_to_experience_site.apex`
> 5. Check **Open Log** and click **Execute**
> 6. Review the debug logs to confirm the service account was added to the Experience Cloud site(s)
>
> **Option B: If Event Bot is a Regular User** (Chatter Free license):
> - The script will detect this and provide guidance
> - You can still proceed to Step 4d.2 - regular Chatter groups will work
> - Site-specific groups will be skipped (Event Bot can't be added to them)
> - If you need site-specific groups, convert Event Bot to a Community User:
>   1. Create a Contact record for Event Bot (if one doesn't exist)
>   2. Go to Setup → Users → Users → Edit Event Bot
>   3. Change User License to a Community license (e.g., "SM Community Plus Login")
>   4. Link to the Contact record
>   5. Then run the script again

**Step 4d.2: Add to All Existing Chatter Groups**

1. In the same **Execute Anonymous Window** (or open a new one)
2. Copy and paste the contents of `scripts/apex/add_chatter_service_to_all_groups.apex`
3. Check **Open Log** and click **Execute**
4. Review the debug logs to confirm the service account was added to all groups

**Step 4d.3: Deploy Flow for Automatic Addition to New Groups**

1. Deploy the Flow `Add_Chatter_Service_To_New_Groups.flow-meta.xml`:
   ```bash
   sf project deploy start --target-org smi --source-dir force-app/main/default/flows/Add_Chatter_Service_To_New_Groups.flow-meta.xml
   ```
2. Verify the Flow is **Active** in Setup → Flows
3. The Flow will automatically add the service account to any new Chatter groups created in the future

**What This Does**:
- Step 4d.1 adds Event Bot as a member of the Experience Cloud site(s), which is required for site-specific Chatter groups
- Step 4d.2 adds Event Bot to all existing Chatter groups (both regular and site-specific)
- Step 4d.3 deploys a Flow that automatically adds Event Bot to any new Chatter groups when they're created
- No manual intervention needed for future groups

**Testing**:
- After Step 4d.1, verify Event Bot appears in Experience Cloud site member lists
- After Step 4d.2, verify Event Bot is a member of all Chatter groups
- After Step 4d.3, create a test Chatter group to verify the Flow automatically adds the service account
- Check group members to confirm the service account was added

**Important Notes**:
- **Order matters**: You must run Step 4d.1 (add to site) before Step 4d.2 (add to groups)
- Site-specific groups require Experience Cloud site membership first
- The script in Step 4d.2 will check site membership and skip site-specific groups if the user isn't a site member
- Regular Chatter groups (not site-specific) will be added regardless of site membership

#### Step 4e: (Optional) Configure Batch to Run as Service Account

To run the batch job as the service account, modify `EventChatterBatchPoster` to implement `Database.Batchable<SObject>` with a constructor that accepts a User ID, or use `System.runAs()` in the schedulable execute method. This is optional - the batch can also run as the user who scheduled it.

**Time**: ~15-20 minutes

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

