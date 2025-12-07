# 🔔 Batch Service: Event Chatter Batch Posting

This automated Salesforce batch job posts rich text notifications to activity group Chatter groups daily, collecting all approved events that haven't been posted yet and posting one comprehensive message per activity group.

---

## Access

* Apex Class: [EventChatterBatchPoster.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterBatchPoster.cls)
* Helper Class: [EventChatterPostHelper.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterPostHelper.cls)
* Scheduled Jobs: [Setup → Scheduled Jobs](https://spokanemountaineers.lightning.force.com/lightning/setup/ScheduledJobs/home)

---

## 🎯 Purpose

This batch service automatically posts rich text notifications to activity group Chatter groups on a daily schedule. It:

- Runs daily at 5:00 AM Pacific Time
- Queries all `Event_Registration__c` records that are approved but haven't been posted yet (`Chatter_Posted__c != true`)
- Groups events by `Activity_Group__c`
- Posts one comprehensive message per activity group containing all events for that group
- Handles high-volume event approvals efficiently (10-20 events at once)
- Leverages Chatter's native notification system for members subscribed to the groups
- Processes any unposted approved event, regardless of when it was approved (ensures no events are missed)

---

## ⚡ Schedule

- **Frequency**: Daily
- **Time**: 5:00 AM Pacific Time
- **Type**: Scheduled Apex Batch Job
- **Cron Expression**: `0 0 5 * * ?`

**Note**: The batch job processes ANY approved event where `Chatter_Posted__c != true`, regardless of when it was approved. This ensures no events are missed, even if the batch job was skipped previously or events were approved before the field was added. Once posted, `Chatter_Posted__c` is set to `true` to prevent duplicate processing.

---

## 🧱 Batch Job Structure

The batch job implements the standard Salesforce batchable pattern:

### 1. Start Method

**Purpose**: Query all approved events that haven't been posted yet

**Query Logic**:
```apex
SELECT Id, Name, Activity_Group__c, Start__c, Location__c, Chatter_Posted__c
FROM Event_Registration__c
WHERE Status__c = 'Approved'
AND Activity_Group__c != null
AND (Chatter_Posted__c != true)
ORDER BY Activity_Group__c, Start__c
```

**Returns**: `Database.QueryLocator` with all qualifying events

**Note**: The query processes ANY approved event where `Chatter_Posted__c != true` (includes `false`, `null`, or any non-true value). This ensures no events are missed, regardless of when they were approved.

### 2. Execute Method

**Purpose**: Process events in batches, group by activity group, and post

**Process**:
1. Receives batch of up to 200 Event_Registration__c records
2. Groups events by `Activity_Group__c` into a Map
3. For each activity group:
   - Finds matching Public Chatter group
   - Calls `EventChatterPostHelper.postBatchToChatterGroup()` with all events for that group
   - Posts single comprehensive message

**Error Handling**:
- If one activity group fails, continues processing other groups
- Logs errors but doesn't throw exceptions
- Ensures batch job completes even if some posts fail

### 3. Finish Method

**Purpose**: Log completion status

**Actions**:
- Queries AsyncApexJob to get execution details
- Logs status, job items processed, and any errors
- Provides summary for monitoring

---

## 🔍 Data Model

### Objects Used

| **Object** | **Purpose** | **Key Fields** |
|:----------:|:-----------:|:--------------:|
| `Event_Registration__c` | Trigger record - the approved event | `Id`, `Name`, `Activity_Group__c`, `Start__c`, `Location__c`, `Status__c` |
| `CollaborationGroup` | Target Chatter group for posting | `Id`, `Name`, `CollaborationType` |

### Relationships

- `Event_Registration__c.Activity_Group__c` → Matches `CollaborationGroup.Name` (Text match)
- Flow queries for Public Chatter groups where `Name = Activity_Group__c`

---

## 📝 Rich Text Message Format

### Single Event Format

When only one event is found for an activity group:

1. **Bold Title**: "New {Activity Group} Event!"
2. **Blank line**
3. **Introduction**: "A new {Activity Group} event has been added to the club calendar!"
4. **Blank line**
5. **Bold Event Name**
6. **Event Details** (separate paragraphs):
   - Leader: {Leader Name} or "TBD"
   - Start: {Date/Time in M/d/yy at h:mma format} or "TBD"
   - Location: {Location} or "Location TBD"
7. **View Event**: URL (auto-linked by Chatter)

### Multiple Events Format (Batch)

When multiple events are found for an activity group:

1. **Bold Title**: "New {Activity Group} Events Added!"
2. **Introduction**: "We've added X new {Activity Group} events to the club calendar:"
3. **Blank line**
4. **For each event**:
   - **Bold Event Name**
   - Leader: {Leader Name}
   - Start: {Date/Time}
   - Location: {Location}
   - View Event: {URL}
   - (blank line between events)

### Example Output (Single Event)

```
**New Hiking Event!**

A new Hiking event has been added to the club calendar!

**Stevens Lakes Snowshoe**
Leader: Tyler Nyman
Start: 1/15/26 at 7:00AM
Location: Mullan, ID
View Event: https://www.spokanemountaineers.org/s/event-registration/a01...
```

### Example Output (Batch)

```
**New Hiking Events Added!**

We've added 3 new Hiking events to the club calendar:

**Glacier Travel Practice**
Leader: John Smith
Start: 7/1/25 at 6:30PM
Location: Clubhouse
View Event: https://www.spokanemountaineers.org/s/event-registration/a01...

**Mountain Summit Hike**
Leader: Jane Doe
Start: 7/5/25 at 8:00AM
Location: Trailhead
View Event: https://www.spokanemountaineers.org/s/event-registration/a02...

**Evening Nature Walk**
Leader: Bob Wilson
Start: 7/10/25 at 6:00PM
Location: Park
View Event: https://www.spokanemountaineers.org/s/event-registration/a03...
```

---

## ⚠️ Edge Cases Handled

1. **No Events Approved**: If no approved events need posting, batch completes with no posts
2. **No Activity Group**: Query filters out events without `Activity_Group__c`
3. **Chatter Group Not Found**: If no matching Public group exists, logs error and continues with other groups
4. **Null Fields**: Provides default values:
   - Missing Name → "Unnamed Event"
   - Missing Activity Group → "Unknown"
   - Missing Start → "TBD"
   - Missing Location → "Location TBD"
5. **Multiple Events Same Group**: Groups all events by activity group and posts single message
6. **Posting Failures**: If one group fails, continues processing other groups
7. **Large Batches**: Processes in batches of 200 records to handle governor limits
8. **Duplicate Prevention**: Uses `Chatter_Posted__c` checkbox to prevent reprocessing events that were already posted, even if they're modified later
9. **No Time Window**: Processes any approved event that hasn't been posted, ensuring no events are missed even if batch job was skipped or events were approved before field was added

## 🔧 Required Setup

**IMPORTANT**: This batch job requires custom fields and a Flow to prevent duplicate processing. See [Event Chatter Batch Setup Guide](event-chatter-batch-setup.md) for details.

**Required Field**:
- `Chatter_Posted__c` (Checkbox) - Tracks if event has been posted to Chatter

**No Flow Required**: The batch job handles setting `Chatter_Posted__c = true` after posting. The field defaults to unchecked for new approved events.

---

## 🔧 Technical Implementation

### EventChatterBatchPoster Class

The batch class implements `Database.Batchable<SObject>` and `Schedulable`:

**Schedulable Interface:**
```apex
public void execute(SchedulableContext ctx) {
    EventChatterBatchPoster batch = new EventChatterBatchPoster();
    Database.executeBatch(batch, 200);
}
```

**Batchable Interface:**
- `start(Database.BatchableContext)` - Returns QueryLocator for all approved events where `Chatter_Posted__c != true`
- `execute(Database.BatchableContext, List<Event_Registration__c>)` - Groups events and posts
- `finish(Database.BatchableContext)` - Logs completion status

**Key Features:**
- Processes in batches of 200 records
- Groups events by Activity_Group__c before posting
- Calls EventChatterPostHelper.postBatchToChatterGroup() for each group
- Comprehensive error handling and logging

See: [EventChatterBatchPoster.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterBatchPoster.cls)

### EventChatterPostHelper Class

The helper class provides batch posting methods:

**Batch Methods:**
```apex
public static void postBatchToChatterGroup(
    String activityGroupName, 
    List<Event_Registration__c> events
)

public static ConnectApi.MessageBodyInput buildBatchRichTextMessageBody(
    List<Event_Registration__c> events, 
    String activityGroup
)
```

**Key Methods:**
- `buildBatchRichTextMessageBody(...)` - Builds formatted message with multiple events
- `postBatchToChatterGroup(...)` - Posts batch message to a single Chatter group
- `buildRichTextMessageBody(Event_Registration__c)` - Single event format
- `addParagraphWithBoldText(...)` - Helper for bold text paragraphs
- `addParagraphText(...)` - Helper for plain text paragraphs
- `addSpacerParagraph(...)` - Helper for blank lines between sections
- `formatDateTime(DateTime)` - Formats dates as "M/d/yy 'at' h:mma" (e.g., "1/22/26 at 7:00AM")

**Connect API Usage:**
The class uses Salesforce's Connect API (`ConnectApi.ChatterFeeds.postFeedElement`) to post rich text messages with proper formatting. This ensures:
- Native Chatter formatting
- Proper paragraph structure
- Bold text support
- Bulleted lists for multiple events
- Automatic URL linking

See: [EventChatterPostHelper.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterPostHelper.cls)

---

## 📊 Monitoring & Troubleshooting

### Check Batch Job Execution

1. Go to **Setup → Scheduled Jobs**
2. Find **Event Chatter Batch Posting - Daily 5am**
3. Review execution history, next run time, and status
4. Click on job to see detailed execution logs

### Check Async Apex Jobs

1. Go to **Setup → Apex Jobs** (or **Monitoring → Apex Jobs**)
2. Filter by class name: `EventChatterBatchPoster`
3. Review job status, records processed, and any errors
4. Click on job to see detailed logs

### Verify Chatter Posts

1. Navigate to the activity group Chatter group (e.g., "Hiking")
2. Look for posts with title "New {Activity Group} Events!" (or "Event!" for single)
3. Posts should appear after the 5am batch job runs
4. Check that all events approved in last 24 hours are included

### Common Issues

| **Issue** | **Possible Cause** | **Solution** |
|:---------:|:------------------:|:------------:|
| No Chatter posts appearing | Batch job not scheduled | Run the scheduling script: `scripts/apex/schedule_event_chatter_batch.apex` |
| No Chatter posts appearing | Events already posted | Verify `Chatter_Posted__c` is not `true` on approved events |
| No Chatter posts appearing | Event not approved | Verify `Status__c = 'Approved'` on Event_Registration__c |
| No Chatter posts appearing | Chatter group not found | Verify Public Chatter group exists with name matching Activity_Group__c |
| No Chatter posts appearing | Activity Group not set | Verify `Activity_Group__c` is populated on Event_Registration__c |
| Batch job not running | Job not scheduled | Schedule the job using the script or manually via Setup → Scheduled Jobs |
| Batch job not running | Job aborted | Check Scheduled Jobs for aborted jobs, reschedule if needed |
| Batch job failing | Apex errors | Check debug logs and Apex Jobs for error details |
| Chatter group not found | Name mismatch | Verify Chatter group name exactly matches Activity_Group__c (case-sensitive) |
| Chatter group not found | Group is Private | Ensure Chatter group is Public (CollaborationType = 'Public') |
| Posting fails | Network/API issues | Check debug logs for Connect API errors |
| Posting fails | User permissions | Verify running user has permission to post to Chatter groups |
| Events missing from post | Already marked as posted | Verify `Chatter_Posted__c` is not `true` on the event. If needed, set to `false` to reprocess |
| Duplicate posts | Multiple batch runs | `Chatter_Posted__c = true` prevents duplicates. Verify field is being set correctly after posting |

### Debug Logs

Enable debug logs for the `EventChatterPostHelper` class to see detailed execution:

1. Go to **Setup → Debug Logs**
2. Create a new trace flag for the user who approves events
3. Set Apex Class to `EventChatterPostHelper`
4. Set log level to `DEBUG`
5. Approve an event and review the logs

Look for:
- "Event Registration not found" - Event query failed
- "Chatter group not found" - Group lookup failed
- "Successfully posted to Chatter group" - Post succeeded
- Any exception messages

### Query Event Registrations

```sql
-- See events that will be processed by batch job (approved but not posted)
SELECT Id, Name, Activity_Group__c, Status__c, Start__c, Location__c, Chatter_Posted__c
FROM Event_Registration__c
WHERE Status__c = 'Approved'
AND Activity_Group__c != null
AND (Chatter_Posted__c != true)
ORDER BY Activity_Group__c, Start__c

-- Check for events without activity groups (won't be processed)
SELECT Id, Name, Activity_Group__c, Status__c, Chatter_Posted__c
FROM Event_Registration__c
WHERE Status__c = 'Approved'
AND (Activity_Group__c = NULL OR Activity_Group__c = '')

-- Count events by activity group (not yet posted)
SELECT Activity_Group__c, COUNT(Id) EventCount
FROM Event_Registration__c
WHERE Status__c = 'Approved'
AND Activity_Group__c != null
AND (Chatter_Posted__c != true)
GROUP BY Activity_Group__c
ORDER BY EventCount DESC

-- See events that have already been posted
SELECT Id, Name, Activity_Group__c, Chatter_Posted__c
FROM Event_Registration__c
WHERE Status__c = 'Approved'
AND Chatter_Posted__c = true
ORDER BY LastModifiedDate DESC
```

### Query Chatter Groups

```sql
-- List all Public Chatter groups
SELECT Id, Name, CollaborationType, MemberCount
FROM CollaborationGroup
WHERE CollaborationType = 'Public'
ORDER BY Name

-- Find groups matching activity groups
SELECT Id, Name
FROM CollaborationGroup
WHERE CollaborationType = 'Public'
AND Name IN ('Hiking', 'Climbing', 'Alpine', 'Conservation')
```

---

## 🔗 Related Components

### Apex Batch Class

The `EventChatterBatchPoster` class provides the batch processing:

**Main Methods:**
- `execute(SchedulableContext)` - Schedules the batch job
- `start(Database.BatchableContext)` - Queries all approved events where `Chatter_Posted__c != true`
- `execute(Database.BatchableContext, List<Event_Registration__c>)` - Groups and posts events
- `finish(Database.BatchableContext)` - Logs completion

**Test Coverage:**
- Comprehensive test coverage for batch execution, grouping, and edge cases
- Tests cover empty batches, missing groups, and multiple events

See: [EventChatterBatchPoster.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterBatchPoster.cls)

### Apex Helper Class

The `EventChatterPostHelper` class provides the posting functionality:

**Batch Methods:**
- `postBatchToChatterGroup(String, List<Event_Registration__c>)` - Posts batch of events to a single group
- `buildBatchRichTextMessageBody(List<Event_Registration__c>, String)` - Builds formatted message with multiple events

**Single Event Methods:**
- `postEventToChatterGroup(List<PostToChatterInput>)` - **Invocable Method** - Posts single event (can be called from Flows)

**Helper Methods:**
- `buildRichTextMessageBody(Event_Registration__c)` - Builds formatted message for single event
- `addParagraphText(...)` - Adds text paragraphs
- `addParagraphWithBoldText(...)` - Adds bold text paragraphs
- `addSpacerParagraph(...)` - Adds blank lines between sections
- `formatDateTime(DateTime)` - Formats dates as "M/d/yy at h:mma"

**Test Coverage:**
- Comprehensive test coverage for both batch and single event methods
- Tests cover all helper methods, edge cases, and error handling

See: [EventChatterPostHelper.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterPostHelper.cls)

---

## 🚀 Future Enhancements

| **Feature** | **Notes** |
|:-----------:|:---------:|
| Reset Posted Flag | Allow admins to reset `Chatter_Posted__c` to reprocess events if needed |
| Multiple Schedule Times | Run multiple times per day if needed (e.g., morning and evening) |
| Service Account Integration | Use dedicated Event Bot service account for consistent posting identity |
| Email Notifications | Add email notifications in addition to Chatter posts (Phase 2) |
| Custom Message Templates | Allow customization of message format per activity group |
| Image Support | Include event images in Chatter posts |
| Multi-group Support | Post to multiple groups if an event spans multiple activity types |
| Engagement Analytics | Track views, clicks, and comments on event posts |
| Batch Size Configuration | Allow configuration of batch size (currently 200) |

---

## 📝 Related Documentation

- [Activity Group Event Notifications](../articles/activity-group-event-notifications.md): Article explaining the feature and implementation
- [Notify Leader on RSVP](notify-leader-on-rsvp.md): Similar notification flow for event leaders
- [Event Participant Redirect](../articles/event-participant-redirect.md): Related solution for event participant functionality

## 📅 Scheduling the Batch Job

To set up the scheduled batch job, run the following Apex script:

**Script**: `scripts/apex/schedule_event_chatter_batch.apex`

This script:
1. Checks for existing scheduled jobs and removes them
2. Schedules the batch job to run daily at 5:00 AM Pacific Time
3. Logs the job ID and next fire time

**Manual Scheduling** (Alternative):
1. Go to **Setup → Apex Classes**
2. Find `EventChatterBatchPoster`
3. Click **Schedule Apex**
4. Set schedule: Daily at 5:00 AM
5. Save

**Verifying Schedule**:
- Go to **Setup → Scheduled Jobs**
- Look for "Event Chatter Batch Posting - Daily 5am"
- Verify next fire time is correct

---

## 🛠 Technical Details

- **API Version**: 65.0
- **Batch Class**: EventChatterBatchPoster (implements Database.Batchable<SObject> and Schedulable)
- **Schedule**: Daily at 5:00 AM Pacific Time (Cron: `0 0 5 * * ?`)
- **Batch Size**: 200 records per batch execution
- **Processing Logic**: Processes any approved event where `Chatter_Posted__c != true` (no time window restriction)
- **Bulk Support**: Yes (handles large volumes efficiently via batch processing)
- **Helper Class**: EventChatterPostHelper.postBatchToChatterGroup
- **Connect API**: Uses ConnectApi.ChatterFeeds.postFeedElement for rich text posting
- **Status**: Active (scheduled job must be set up)

---

## 📞 Support

For issues or questions about this flow, contact the tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
