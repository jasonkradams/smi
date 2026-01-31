# Fixing Missing Approval Email Notifications

_Published: January 2026 | Category: Salesforce Solutions_

## The Problem We Solved

Our activity group chairs recently stopped receiving email notifications when new events were submitted for approval. The Chalet Chair reported that she was no longer getting emails when members submitted new Chalet events that needed her approval.

This was a critical issue because:

- Approvers had no way to know events were waiting for review
- Events could sit in limbo indefinitely
- Members creating events had no visibility into why their events weren't being approved

## Investigation and Root Cause

Working with our Agentforce AI assistant, we conducted a thorough investigation:

1. **Verified user settings** - The user's email preferences were correctly configured
2. **Checked group memberships** - The user was properly added to the Chalet Committee and Chalet Approval Queue
3. **Reviewed approval processes** - The Chalet_Approvals process was active and routing correctly
4. **Analyzed platform data** - No `ProcessInstanceWorkitem` or `EmailMessage` records were being created for recent approvals

### The Surprising Discovery

The approval queues had **never** had email addresses configured, yet emails were being sent before. This meant the issue wasn't a configuration change on our end—something had changed in Salesforce's default behavior.

### Root Cause

Salesforce's platform behavior changed regarding automatic approval notifications. When an approval step assigns work to a queue:

- **Previously**: Salesforce would automatically send notification emails to queue members
- **Now**: Emails are only sent when explicit Email Alert actions are configured

This is consistent with Salesforce's direction toward explicit automation configuration and the new Flow Approval Orchestration feature introduced in Spring '25.

## Our Solution

We added explicit Email Alert actions to all 9 Event Registration approval processes. This guarantees that notification emails are sent regardless of platform behavior changes.

### What We Built

1. **9 Email Alerts** - One for each activity group committee:
    - Chalet, Climbing, Clubwide, Conservation, Hiking
    - Mountain Biking, Paddling, Road Biking, Skiing

2. **Updated Email Template** - Enhanced the approval request email with event details:
    - Event name
    - Start date/time and location
    - Event leader name
    - Direct link to approve/reject

3. **Updated Approval Processes** - Added the email alert to the initial submission actions

### Sample Email

When a new event is submitted, approvers now receive:

```
Subject: A New Chalet Event Has Been Requested For Spokane Mountaineers

Hi,

A member has requested your approval for the following event:

Winter Cabin Weekend
2026-02-15 at Chalet
Led by: Event Leader Name

Please click this link to approve or reject this event:
https://www.spokanemountaineers.org/p/process/ProcessInstanceWorkitemWizardStageManager?id=...

Thank you,
Spokane Mountaineers
```

## Benefits

- **Immediate fix** - Approvers started receiving emails right away
- **Explicit configuration** - Not dependent on platform defaults
- **Future-proof** - Will continue working regardless of Salesforce updates
- **Better email content** - Approvers can see event details at a glance

## Lessons Learned

1. **Don't rely on default behaviors** - Platform defaults can change without warning
2. **Explicit is better than implicit** - Configure automations explicitly rather than relying on built-in behaviors
3. **AI-assisted debugging** - Using Agentforce to query platform data helped identify the root cause quickly
4. **Document your automations** - Having clear documentation helps troubleshoot issues faster

## Future Plans

We're evaluating migrating to Salesforce's new **Flow Approval Orchestration** feature (introduced Spring '25, enhanced Winter '26) which provides:

- Modern, declarative approval management
- Better debugging and error handling
- Built-in recall functionality
- More flexibility for complex approval scenarios

## Technical Details

For the complete technical implementation, see our [Event Approval Email Alerts automation documentation](../automation/event-approval-email-alerts.md).

## Questions?

If you have questions about this solution or encounter any issues with approval notifications, contact the tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
