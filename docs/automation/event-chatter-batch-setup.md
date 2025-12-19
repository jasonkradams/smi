# Event Chatter Batch Posting - Field Setup

## Problem

The batch job needs to prevent duplicate processing when:

1. Event is approved → processed → posted to Chatter
2. Event leader modifies event details → LastModifiedDate updates
3. Batch job runs again → re-processes the same event → duplicate post

## Solution

Use a simple checkbox field to track which events have been posted. The batch job processes ANY approved event where `Chatter_Posted__c != true`, ensuring no events are missed while preventing duplicates.

## Required Field

**Field Name**: `Chatter_Posted__c`

- **Type**: Checkbox
- **Label**: "Chatter Posted"
- **Default Value**: Unchecked
- **Description**: "Indicates if this event has been posted to Chatter. Set to true after batch job posts the event."

## Implementation Steps

1. **Create the Field**:
    - Go to Setup → Object Manager → Event Registration
    - Create the checkbox field `Chatter_Posted__c`
    - Add to page layouts if needed (optional, mainly used by automation)

2. **Deploy Batch Class**:
    - The batch class queries events where `Chatter_Posted__c != true`
    - After posting, it sets `Chatter_Posted__c = true`

## How It Works

1. **Event Approval**: When an event is approved (`Status__c = 'Approved'`), `Chatter_Posted__c` is unchecked (default)
2. **Batch Query**: Batch job queries ALL approved events where `Chatter_Posted__c != true`
    - This includes events where the field is `false`, `null`, or any value other than `true`
    - No time window restriction - processes any unposted approved event
3. **Posting**: Batch job posts events to Chatter groups, grouped by activity group
4. **Tracking**: Batch job sets `Chatter_Posted__c = true` after posting
5. **Prevention**: Future batch runs skip events where `Chatter_Posted__c = true`, even if the event is modified later

## Benefits of This Approach

- **Simple**: Only requires one checkbox field
- **Robust**: Catches any events that might have been missed (batch failures, field added later, etc.)
- **No Time Window**: Processes events regardless of when they were approved
- **Duplicate Prevention**: Once posted, events are never reprocessed, even if modified

## Testing

After setup, test the batch job:

1. Create an `Event_Registration__c` with `Status__c = 'Approved'`
2. Verify `Chatter_Posted__c` is unchecked (default)
3. Run batch job manually: `Database.executeBatch(new EventChatterBatchPoster(), 200);`
4. Verify events are posted to Chatter groups
5. Verify `Chatter_Posted__c` is set to true on the events
6. Modify the event (change Location, etc.)
7. Run batch job again
8. Verify the event is NOT reprocessed (Chatter_Posted\_\_c = true prevents it)
