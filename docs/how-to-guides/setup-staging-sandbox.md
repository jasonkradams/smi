# Setting Up Staging Sandbox for Experience Builder

This guide walks through setting up a staging sandbox to match your production Experience Cloud site configuration, including Activity Group pages and Managed Content folders.

---

## 🎯 Overview

When setting up a new sandbox, you may encounter errors in Experience Builder such as:

- "The Managed Content Folder Definition, Activity_Groups, is not valid."
- "We can't load the <name> component because it's not supported by any data."

This guide helps you resolve these issues by setting up the necessary components and data.

---

## 📋 Prerequisites

- Access to your staging sandbox
- System Administrator permissions
- Experience Cloud site already created (or cloned from production)

---

## 🔧 Step 1: Create Activity Group Chatter Groups

The EventChatterPostHelper requires Chatter groups with names matching your activity groups. Create these manually in Salesforce.

### Required Activity Groups

Create public Chatter groups for:

- Hiking
- Climbing
- Backpacking
- Skiing
- Mountaineering
- Cycling

Plus any additional activity groups used in your `Event_Registration__c` records.

### Creating Groups Manually

1. Navigate to **Chatter** → **Groups**
2. Click **New Group**
3. Enter the activity group name (e.g., "Hiking")
4. Set **Access Type** to **Public**
5. Click **Save**
6. Repeat for each activity group

### Verify Groups Were Created

1. Navigate to **Chatter** in your org
2. Click **Groups** in the left sidebar
3. Verify each activity group appears as a public Chatter group

### ⚠ Troubleshooting: Flow Error When Creating Groups

If you see errors like:

```
"We can't save this record because the 'Add Chatter Service To New Groups' process failed"
"INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY"
```

This means the **"Add Chatter Service To New Groups"** flow is trying to automatically add the Event Bot service account to new groups, but it's failing because:

1. **The Event Bot service account doesn't exist** in staging, OR
2. **The service account exists but isn't a member** of the Experience Cloud site (for site-specific groups)

#### Solution Options

**Option 1: Create the Event Bot Service Account (Recommended)**

1. Create a user with username: `eventbot@spokanemountaineers.org.smi`
2. Add the user to your Experience Cloud site (if groups are site-specific)
3. See `scripts/apex/add_event_bot_to_experience_site.apex` for help adding the bot to the site

**Option 2: Temporarily Deactivate the Flow**

1. Go to **Setup** → **Flows**
2. Find **"Add Chatter Service To New Groups"**
3. Click **Deactivate**
4. Create the groups manually
5. After groups are created, you can:
    - Reactivate the flow, OR
    - Add the service account using `scripts/apex/add_chatter_service_to_all_groups.apex`

---

## 📁 Step 2: Create Managed Content Folder

Managed Content folders are created through the Experience Builder UI and cannot be deployed via metadata.

### Manual Creation Steps

1. Navigate to **Setup** → **Digital Experiences** → **All Sites**
2. Click **Builder** next to your Experience Cloud site
3. In Experience Builder, click the **Settings** gear icon (top right)
4. Select **Content** from the settings menu
5. Click **New Folder** or **Manage Folders**
6. Create a new folder with:
    - **Name**: `Activity_Groups`
    - **Type**: Managed Content Folder
7. Save the folder

### Alternative: Check Production Setup

If you have access to production, you can:

1. Navigate to the same location in production
2. Note the exact folder name and configuration
3. Replicate it in staging

---

## 📊 Step 3: Create Test Data

Experience Builder components need data to display. Create test events for each activity group.

### Using the Script

1. Open **Developer Console** in your staging sandbox
2. Go to **Debug** → **Open Execute Anonymous Window**
3. Copy and paste the contents of `scripts/apex/create_test_events_by_activity_group.apex`
4. Check **Open Log** and click **Execute**
5. Review the debug logs to confirm events were created

### What This Creates

- At least 3 approved events per activity group
- Events scheduled 7+ days in the future
- Events with `Chatter_Posted__c = false` (ready for batch processing)

### Verify Events Were Created

1. Navigate to **Event Registration** tab (or object)
2. Filter by `Status__c = 'Approved'`
3. Group by `Activity_Group__c` to see events per group

---

## 🧩 Step 4: Verify Experience Builder Pages

After setting up the above, verify your Experience Builder pages load correctly.

### Check Activity Group Pages

1. Navigate to **Digital Experiences** → **All Sites** → **Builder**
2. Try navigating to each Activity Group page (e.g., "Climbing", "Hiking")
3. Verify no errors appear
4. Check that components display data correctly

### Common Issues and Fixes

| Error                                         | Cause                              | Solution                    |
| --------------------------------------------- | ---------------------------------- | --------------------------- |
| "Managed Content Folder Definition not valid" | Folder doesn't exist               | Create the folder in Step 2 |
| "Component not supported by any data"         | No records match component filters | Create test data in Step 3  |
| "Chatter group not found"                     | Chatter groups missing             | Run script in Step 1        |

---

## 🔄 Step 5: Deploy Metadata (Optional)

If you need to deploy custom components, classes, or other metadata:

```bash
# Deploy to staging
sf project deploy start --target-org staging
```

Or use the Salesforce CLI to deploy specific components.

---

## ✅ Verification Checklist

- [ ] Chatter groups created for all activity groups
- [ ] Managed Content folder "Activity_Groups" exists
- [ ] Test events created for each activity group
- [ ] Experience Builder pages load without errors
- [ ] Components display data correctly
- [ ] Navigation works between activity group pages

---

## 🐛 Troubleshooting

### Components Still Show "No Data" Error

1. **Check component filters**: Verify the component's SOQL/record filters match your test data
2. **Check field values**: Ensure required fields are populated on test records
3. **Check permissions**: Verify your user profile has access to the objects/fields

### Managed Content Folder Still Not Found

1. **Verify exact name**: Check for typos - it must match exactly (case-sensitive)
2. **Check folder type**: Must be "Managed Content Folder", not "Content Folder"
3. **Refresh Experience Builder**: Close and reopen the builder after creating the folder

### Chatter Groups Not Found by EventChatterPostHelper

1. **Verify group names**: Group names must exactly match `Activity_Group__c` field values
2. **Check group type**: Groups should be "Public" for visibility
3. **Check permissions**: Ensure the running user has access to the groups

### Flow Preventing Group Creation

If groups fail to create due to the "Add Chatter Service To New Groups" flow:

1. **Check if Event Bot exists**: Query `SELECT Id, Username FROM User WHERE Username = 'eventbot@spokanemountaineers.org.smi'`
2. **Create the service account** if missing (see deployment guide), OR
3. **Temporarily deactivate the flow** (Setup → Flows → "Add Chatter Service To New Groups" → Deactivate)

---

## 📚 Related Documentation

- [Activity Group Event Notifications](../articles/activity-group-event-notifications.md)
- [Event Chatter Batch Setup](../automation/event-chatter-batch-setup.md)
- [Website Editing Guide](website-editing.md)

---

## 💡 Tips

- **Keep staging in sync**: Regularly refresh test data to match production patterns
- **Document customizations**: Note any manual UI configurations that can't be deployed
- **Test thoroughly**: Verify all activity group pages work before deploying to production

---

> ✨ _Need help? Check the debug logs from the scripts for detailed information about what was created or any errors encountered._
