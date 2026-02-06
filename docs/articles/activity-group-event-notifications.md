# Keeping Members Informed: Activity Group Event Notifications

_Published: November 26, 2025 | Category: Community Solutions_

## The Problem We Solved

Members of the Spokane Mountaineers were missing out on events they would have loved to attend. When event leaders posted new hikes, climbs, or other activities, members had no way to know unless they happened to check the website. This led to:

- **Missed opportunities** - Active members missing events they would have attended
- **Lower engagement** - Event leaders feeling like their posts went unseen
- **Manual work** - Admins and chairs having to manually promote events through email, Slack, or word of mouth
- **Diminished value** - The website wasn't serving as the central engagement tool it could be

There was no way for members to automatically be notified when new events were posted for their favorite activity groups (like "Hiking" or "Climbing").

## Our Solution: Activity Group Chatter Notifications

We built an automated batch notification system that posts new event announcements directly to activity group Chatter groups. Now:

- **Automatic batch notifications** are posted to Chatter daily at 5am Pacific
- **Batch processing** collects all approved events that haven't been posted yet and groups them by activity group
- **Rich text formatting** makes posts visually appealing and easy to read
- **Multiple events per post** - When leaders approve 10-20 events at once, they're all included in a single comprehensive post
- **Direct links** to event registration pages for easy access
- **Leverages existing subscriptions** - Members who subscribe to Chatter groups automatically see notifications
- **No additional setup** - Works with existing Chatter group structure

## How It Works

### The Batch Notification Service

The system runs as a scheduled batch job:

1. **Daily Schedule** - Runs every day at 5:00 AM Pacific Time
2. **Event Collection** - Queries all `Event_Registration__c` records that are approved but haven't been posted yet (`Chatter_Posted__c != true`)
3. **Grouping** - Events are automatically grouped by `Activity_Group__c`
4. **Batch Posting** - One comprehensive Chatter post is created per activity group containing all events for that group
5. **Members Notified** - All members subscribed to those Chatter groups see the notifications in their feed

### Rich Text Formatting

The notifications use Salesforce's Connect API to create beautifully formatted Chatter posts with:

- **Bold headings** - "New {Activity Group} Event!" (singular) or "New {Activity Group} Events Added!" (plural)
- **Event count** - "We've added X new {Activity Group} events to the club calendar:"
- **Structured event details** - Each event shown with:
    - Bold event name
    - Leader, Start date/time, Location
    - Direct link to event registration page
- **Simplified date format** - Compact "M/d/yy at h:mma" format (e.g., "1/15/26 at 7:00AM")
- **Professional formatting** - Clean, readable layout that matches Chatter's native styling

### Smart Group Matching

The system automatically matches events to Chatter groups:

- **Name-based matching** - The `Activity_Group__c` field on the event must match the `Name` of a Public Chatter group
- **Automatic lookup** - The system finds the correct group without manual configuration
- **Error handling** - If a group isn't found, the flow logs an error but doesn't break the event approval process

## What Members See

### Before Our Solution

- No way to automatically know about new events
- Had to manually check the website for new events
- Missed events they would have attended
- No centralized notification system

### After Our Solution

- See new event notifications automatically in their subscribed Chatter groups
- Get event details directly in their Chatter feed
- Click through to view full event registration
- Can comment, like, and share event announcements
- Leverage existing Chatter subscription system

## The Technical Approach

### What We Built

1. **Apex Batchable Class** - `EventChatterBatchPoster` that implements `Database.Batchable<SObject>` and `Schedulable` for daily batch processing
2. **Apex Helper Class** - `EventChatterPostHelper` with methods for posting single and batch events to Chatter groups
3. **Rich Text Builder** - Methods to construct properly formatted Chatter posts using Connect API, including batch formatting with multiple events
4. **Scheduled Job** - Runs daily at 5:00 AM Pacific Time to process all approved events that haven't been posted yet
5. **Comprehensive Tests** - Full test coverage for both batch and helper classes ensuring reliability

### Why This Approach Works

- **Non-disruptive** - Works with existing `Event_Registration__c` and Chatter group structure
- **Scalable** - Handles bulk event approvals efficiently
- **Maintainable** - Uses standard Salesforce tools (Flows, Apex, Connect API)
- **Extensible** - Easy to add more formatting or features in the future
- **User-friendly** - Leverages Chatter's native notification system that members already use

## Key Features

### Rich Text Message Formatting

The `EventChatterPostHelper` class builds rich text messages with:

- **Bold title**: "New {Activity Group} Event!"
- **Introduction paragraph**: Explains that a new event has been added
- **Event details**: Name, start date/time, and location
- **View Event link**: Direct link to the event registration page

### Automatic Group Discovery

The system automatically finds the correct Chatter group:

```apex
// Finds the Chatter group by matching Activity_Group__c to group Name
List<CollaborationGroup> groups = [
    SELECT Id, Name
    FROM CollaborationGroup
    WHERE Name = :activityGroupName
    AND CollaborationType = 'Public'
    LIMIT 1
];
```

### Error Handling

The implementation is designed to be resilient:

- **Missing groups** - Logs error but doesn't break event approval
- **Missing events** - Handles cases where event record isn't found
- **Null fields** - Provides default values for missing event data
- **Test context** - Skips actual posting during test execution

### Invocable Method

The helper class provides an invocable method that can be called from Flows:

```apex
@InvocableMethod(label='Post Event to Chatter Group')
public static void postEventToChatterGroup(
    List<PostToChatterInput> inputs
)
```

This makes it easy to integrate with any Flow that needs to post event notifications.

## Results and Impact

### Member Engagement

✅ Members automatically see new events in their subscribed Chatter groups  
✅ Event leaders get visibility for their approved events  
✅ Website becomes more integrated with Chatter for notifications  
✅ Reduced manual promotion work for admins  
✅ Leverages existing Chatter subscription system

### Technical Benefits

✅ Scalable architecture that handles growth  
✅ Comprehensive test coverage (100% passing)  
✅ Well-documented for future maintenance  
✅ Extensible design for future features  
✅ Uses standard Salesforce APIs (Connect API)

## For Administrators

### How It Works

The batch job runs automatically:

1. **Scheduled Execution** - Runs daily at 5:00 AM Pacific Time via Salesforce's scheduled job system
2. **Event Query** - Queries all `Event_Registration__c` records where:
    - `Status__c = 'Approved'`
    - `Activity_Group__c != null`
    - `Chatter_Posted__c != true` (includes `false`, `null`, or any non-true value)
3. **Grouping** - Events are automatically grouped by `Activity_Group__c`
4. **Batch Posting** - For each activity group:
    - Finds the matching Public Chatter group
    - Builds a rich text message with all events for that group
    - Posts a single comprehensive message to the Chatter group
5. **Tracking** - After posting, sets `Chatter_Posted__c = true` to prevent duplicate processing

### Chatter Group Requirements

For notifications to work, you need:

- **Public Chatter groups** with names matching activity group values
- **Group names** must exactly match `Activity_Group__c` values (e.g., "Hiking", "Climbing")
- **Groups must exist** before events are approved

### Monitoring

**Check Flow Execution:**

1. Go to **Setup → Flows**
2. Find **Notify Subscribers New Event**
3. Review **Interview Logs** to see execution history

**Check Chatter Posts:**

- Navigate to the activity group Chatter group
- Look for posts titled "New {Activity Group} Event!"
- Posts appear immediately after event approval

**Query Event Registrations:**

```sql
-- See recently approved events
SELECT Id, Name, Activity_Group__c, Status__c, Start__c
FROM Event_Registration__c
WHERE Status__c = 'Approved'
ORDER BY LastModifiedDate DESC
LIMIT 10
```

### Troubleshooting

**No Chatter posts appearing:**

- Verify `Event_Registration__c` records have `Status__c = 'Approved'` and `Chatter_Posted__c != true`
- Check that `Activity_Group__c` field is populated
- Verify a Public Chatter group exists with a name matching the `Activity_Group__c` value
- Check that the scheduled batch job is running (Setup → Apex Jobs)
- Review batch job execution logs for errors
- Check debug logs for EventChatterBatchPoster and EventChatterPostHelper errors

**Chatter group not found:**

- Verify the Chatter group name exactly matches the `Activity_Group__c` value (case-sensitive)
- Ensure the group is Public (not Private or Unlisted)
- Check that the group exists and is active

**Batch job not running:**

- Verify the scheduled job exists (Setup → Scheduled Jobs)
- Check that the job is scheduled for 5:00 AM Pacific Time
- Verify the job hasn't been aborted or failed
- Check AsyncApexJob records for execution history
- Manually trigger the batch job to test: `Database.executeBatch(new EventChatterBatchPoster(), 200);`

**Rich text formatting issues:**

- The Connect API handles formatting automatically
- Verify event fields (Name, `Start__c`, `Location__c`) are populated for best results
- Check debug logs if formatting appears incorrect

## Technical Implementation Details

### EventChatterBatchPoster Class

The batch class provides:

**Schedulable Interface:**

- `execute(SchedulableContext)` - Schedules the batch job to run daily at 5am Pacific

**Batchable Interface:**

- `start(Database.BatchableContext)` - Queries all approved events where `Chatter_Posted__c != true`
- `execute(Database.BatchableContext, List<Event_Registration__c>)` - Groups events by activity group and posts
- `finish(Database.BatchableContext)` - Logs completion status

**Key Features:**

- Processes events in batches of 200 records
- Groups events by Activity_Group\_\_c before posting
- Posts one comprehensive message per activity group
- Handles errors gracefully (continues processing other groups if one fails)

See: [EventChatterBatchPoster.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterBatchPoster.cls)

### EventChatterPostHelper Class

The helper class provides:

**Batch Methods:**

- `postBatchToChatterGroup(String, List<Event_Registration__c>)` - Posts batch of events to a single group
- `buildBatchRichTextMessageBody(List<Event_Registration__c>, String)` - Builds formatted message with multiple events

**Single Event Methods:**

- `postEventToChatterGroup(List<PostToChatterInput>)` - Invocable method for single event posting (legacy)

**Helper Methods:**

- `buildRichTextMessageBody(Event_Registration__c)` - Constructs formatted message for single event
- `addParagraphText(...)` - Helper for adding text paragraphs
- `addParagraphWithBoldText(...)` - Helper for adding bold text paragraphs
- `addSpacerParagraph(...)` - Helper for adding blank lines between sections
- `formatDateTime(DateTime)` - Formats dates as "M/d/yy at h:mma"

**Key Features:**

- Uses Connect API for rich text formatting
- Handles null fields gracefully with defaults
- Supports both single and batch posting formats
- Comprehensive error handling and logging

See: [EventChatterPostHelper.cls](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/EventChatterPostHelper.cls)

### Batch Job Structure

The `EventChatterBatchPoster` batch job is efficient and scalable:

1. **Schedule**: Runs daily at 5:00 AM Pacific Time
2. **Query**: Finds all events approved in last 24 hours
3. **Grouping**: Automatically groups events by Activity_Group\_\_c
4. **Posting**: Creates one comprehensive post per activity group
5. **Error Handling**: Continues processing even if one group fails

This batch approach handles high-volume event approvals efficiently and reduces Chatter noise by consolidating multiple events into single posts.

## Future Enhancements

We're planning several improvements:

1. **Reset Posted Flag** - Allow admins to reset `Chatter_Posted__c` to reprocess events if needed
2. **Multiple Schedule Times** - Run multiple times per day if needed
3. **Email Notifications** - Add email notifications in addition to Chatter posts (Phase 2)
4. **Custom Templates** - Allow customization of message format per activity group
5. **Image Support** - Include event images in Chatter posts
6. **Multi-group Support** - Post to multiple groups if an event spans multiple activity types
7. **Analytics** - Track engagement metrics (views, clicks, comments)
8. **Service Account Integration** - Use dedicated service account (`sm-client@prolocity.com`) for consistent posting identity

## Key Takeaways

This solution demonstrates how automation can significantly improve member engagement while reducing manual work. By building on Salesforce's existing Chatter infrastructure, we created a solution that:

- **Solves a real problem** - Members automatically see new events they're interested in
- **Scales automatically** - Handles growth without additional configuration
- **Maintains simplicity** - Clean, focused implementation that's easy to understand
- **Leverages existing tools** - Uses Chatter groups members already subscribe to
- **Professional presentation** - Rich text formatting makes notifications stand out

The approach balances simplicity with functionality, providing automatic notifications that keep members informed while integrating seamlessly with their existing Chatter workflow.

---

**For Technical Details**: See the [automation documentation](../automation/notify-subscribers-new-event.md) for complete flow structure, code examples, and troubleshooting information.
