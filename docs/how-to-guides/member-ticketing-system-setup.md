# Member Ticketing System: Deployment and Configuration Guide

This guide provides step-by-step instructions for deploying and configuring the Member Ticketing System for Experience Cloud members.

## Overview

The Member Ticketing System enables Experience Cloud members to submit technical issues, feature requests, account access problems, and general feedback directly through the community portal. Tickets are automatically routed to appropriate queues and members receive email notifications on updates.

## Prerequisites

- Salesforce org with Experience Cloud enabled
- Administrator access to Setup
- Access to Experience Builder for configuring pages
- Sandbox environment for testing (recommended)

## Deployment Steps

### Phase 1: Deploy Metadata Components

#### 1. Deploy Case Object Customizations

Deploy the Case object customizations including record types and fields:

```bash
sf project deploy start \
    --source-dir force-app/main/default/objects/Case \
    --target-org your-org-alias
```

**What this deploys:**
- Case Record Types: Technical Bug, Feature Request, Account Access, General Feedback
- Custom Field: Related_User__c (formula field)

#### 2. Deploy Apex Classes

Deploy the Apex helper classes and test classes:

```bash
sf project deploy start \
    --source-dir force-app/main/default/classes/TicketSubmissionHelper.cls \
    --source-dir force-app/main/default/classes/TicketSubmissionHelperTest.cls \
    --source-dir force-app/main/default/classes/TicketQueryHelper.cls \
    --source-dir force-app/main/default/classes/TicketQueryHelperTest.cls \
    --test-level RunSpecifiedTests \
    --tests TicketSubmissionHelperTest,TicketQueryHelperTest \
    --target-org your-org-alias
```

**What this deploys:**
- `TicketSubmissionHelper` - Methods for creating tickets and adding comments
- `TicketQueryHelper` - Methods for querying tickets and comments
- Test classes for both helpers

#### 3. Deploy Lightning Web Components

Deploy all three Lightning Web Components:

```bash
sf project deploy start \
    --source-dir force-app/main/default/lwc/ticketSubmissionForm \
    --source-dir force-app/main/default/lwc/memberTicketList \
    --source-dir force-app/main/default/lwc/ticketDetail \
    --target-org your-org-alias
```

**What this deploys:**
- `ticketSubmissionForm` - Form for submitting new tickets
- `memberTicketList` - List view of member's tickets
- `ticketDetail` - Detailed ticket view with comments

### Phase 2: Configure Queues (Manual Setup)

Queues cannot be deployed via metadata and must be created manually in the Salesforce UI.

#### 1. Create Technical Support Queue

1. Navigate to **Setup** → **Queues** (Quick Find: "Queues")
2. Click **New**
3. Configure:
   - **Label**: `Technical Support Queue`
   - **Queue Name**: `Technical Support Queue`
   - **Queue Email**: (Optional) Email address for notifications
   - **Supported Objects**: Select **Case**
   - **Queue Members**: Add technical team members
4. Click **Save**

#### 2. Create Product Feedback Queue

1. Click **New** on the Queues page
2. Configure:
   - **Label**: `Product Feedback Queue`
   - **Queue Name**: `Product Feedback Queue`
   - **Queue Email**: (Optional) Email address for notifications
   - **Supported Objects**: Select **Case**
   - **Queue Members**: Add technical team members and stakeholders
3. Click **Save**

**Queue Assignment:**
- Technical Bug and Account Access tickets → Technical Support Queue
- Feature Request and General Feedback tickets → Product Feedback Queue

> **Note**: Queue assignment is handled automatically in the `TicketSubmissionHelper.createCase()` method based on record type.

### Phase 3: Configure Permissions (Manual Setup)

#### 1. Create Permission Set: Member Ticket Access

1. Navigate to **Setup** → **Permission Sets** (Quick Find: "Permission Sets")
2. Click **New**
3. Configure:
   - **Label**: `Member Ticket Access`
   - **API Name**: `Member_Ticket_Access`
   - **Description**: `Permission set for Experience Cloud members to submit and view tickets`
4. Click **Save**

#### 2. Configure Object Permissions

1. On the Permission Set detail page, click **Object Settings** → **Case**
2. Click **Edit**
3. Set permissions:
   - **Read**: ✅ Own Records
   - **Create**: ✅
   - All other permissions: ❌
4. Click **Save**

#### 3. Configure Field Permissions

1. On the Permission Set detail page, click **Object Settings** → **Case** → **Field Permissions**
2. Configure field access:
   - **Subject**: Read/Edit ✅ (automatically populated)
   - **Description**: Read/Edit ✅
   - **Priority**: Read/Edit ✅
   - **Status**: Read ✅ (Edit disabled for members - set by agents)
   - **Type**: Read ✅ (Record Type name)
   - **Case Origin**: Read ✅
   - **ContactId**: Read ✅ (automatically populated)
   - **OwnerId**: Read ✅ (shows queue or assigned agent)
   - **RecordTypeId**: Read ✅ (shows ticket type)
   - **Related_User__c**: Read ✅ (formula field)
   - **All other fields**: Use default settings (typically Read only or No access)
3. Click **Save**

#### 4. Note on Case Comment Permissions

CaseComment is a standard Salesforce object, but it does **not** appear separately in Permission Sets. Case Comment access is automatically controlled through the parent **Case** object permissions:

- If a user has **Read** access to a Case, they can see published Case Comments for that Case
- If a user has **Create** access to a Case, they can create new Case Comments on that Case
- Only published comments (`IsPublished = true`) are visible to Experience Cloud members

**No separate CaseComment object permissions are needed** - access is inherited from Case permissions.

#### 5. Assign Permission Set to Experience Cloud Profiles

1. On the Permission Set detail page, click **Manage Assignments**
2. Click **Add Assignments**
3. Select Experience Cloud member profiles
4. Click **Assign**

#### 6. Create Permission Set: Technical Team Agent

1. Navigate to **Setup** → **Permission Sets** → **New**
2. Configure:
   - **Label**: `Technical Team Agent`
   - **API Name**: `Technical_Team_Agent`
   - **Description**: `Full access to Cases for technical team members`
3. Click **Save**

#### 7. Configure Agent Permissions

1. On the Permission Set detail page, click **Object Settings** → **Case** → **Edit**
2. Set all permissions to ✅ **All Records**
3. Click **Save**
4. Repeat for **Case Comment** object

#### 8. Assign Agent Permission Set

1. Click **Manage Assignments**
2. Assign to technical team members

### Phase 4: Configure Sharing Settings

#### 1. Case Object Sharing Settings

1. Navigate to **Setup** → **Sharing Settings**
2. Find **Case** in the list
3. Configure:
   - **Organization-Wide Default**: **Private**
   - **Grant Access Using Hierarchies**: ✅ (optional, if using role hierarchy)

#### 2. Create Sharing Rule (Optional)

If you want members to see their tickets automatically:

1. Navigate to **Setup** → **Sharing Settings** → **Case Sharing Rules**
2. Click **New**
3. Configure:
   - **Label**: `Member Ticket Access`
   - **Share With**: Members based on criteria
   - **Access Level**: **Read/Write**
   - **Sharing Rule Criteria**: `ContactId equals Contact.Id`

> **Note**: With Organization-Wide Default set to Private and proper permission set, members can only see Cases where they are the Contact. This is usually sufficient without additional sharing rules.

### Phase 5: Configure Experience Cloud Pages

#### 1. Create Submit Ticket Page

1. Navigate to **Experience Builder** → **Your Site** → **Builder**
2. Click **Pages** → **New** → **Standard Page**
3. Name it `Submit Ticket`
4. Set URL: `/support/submit-ticket`
5. Add components:
   - **ticketSubmissionForm** component
     - The form will automatically show when the component loads on this page
     - No additional configuration needed
6. Save and publish

#### 2. Create My Tickets Page

1. Create a new page: `My Tickets`
2. Set URL: `/support/my-tickets`
3. Add components:
   - **memberTicketList** component
4. Save and publish

#### 3. Create FAQ Page

1. Create a new page: `FAQ`
2. Set URL: `/support/faq`
3. Add content:
   - Add standard Rich Text or CMS Content components with FAQ content
   - Include common questions about the ticketing system, expected response times, etc.
4. Save and publish

#### 4. Create Ticket Detail Page

1. Create a new page: `Ticket Detail`
2. Set URL: `/support/ticket/:recordId` (dynamic parameter where `:recordId` is the Case ID)
3. Add components:
   - **ticketDetail** component
4. Configure component:
   - The component automatically extracts the Case ID from the URL path
   - No additional configuration needed - the `recordId` property is optional
   - The component reads from the URL pattern `/support/ticket/[CASE_ID]`
5. Save and publish

**Note**: The `ticketDetail` component automatically extracts the Case ID from the URL path. If you're using Experience Builder's page parameters, you can optionally set the `recordId` property, but it's not required as the component will read it from the URL automatically.

#### 5. Configure Support Dropdown Navigation

1. In Experience Builder, go to **Navigation Menu**
2. Add new menu item:
   - **Label**: `Support`
   - **Type**: **Navigation Menu** (dropdown)
3. Under the Support menu, add three sub-items:
   
   **Item 1: Submit Ticket**
   - **Label**: `Submit Ticket`
   - **URL**: `/support/submit-ticket`
   - **Target**: Same Window
   
   **Item 2: My Tickets**
   - **Label**: `My Tickets`
   - **URL**: `/support/my-tickets`
   - **Target**: Same Window
   
   **Item 3: FAQ**
   - **Label**: `FAQ`
   - **URL**: `/support/faq`
   - **Target**: Same Window
4. Save and publish

**Navigation Structure:**
```
Support (dropdown)
  ├── Submit Ticket → /support/submit-ticket
  ├── My Tickets → /support/my-tickets
  └── FAQ → /support/faq
```

### Phase 6: Configure Email Templates and Notifications (Manual Setup)

#### 1. Create Email Template: Ticket Created Confirmation

1. Navigate to **Setup** → **Email Templates** → **Classic Email Templates**
2. Click **New Template**
3. Select **Text** format
4. Configure:
   - **Folder**: Select a folder (create new if needed)
   - **Template Name**: `Ticket Created Confirmation`
   - **Subject**: `Your support ticket #[CaseNumber] has been received`
   - **Body**: (See template below)
5. Click **Save**

**Email Template Body:**
```
Hello {!Case.Contact.Name},

Thank you for contacting us. We have received your support ticket and our team will review it shortly.

Ticket Details:
- Case Number: {!Case.CaseNumber}
- Subject: {!Case.Subject}
- Type: {!Case.RecordType.Name}
- Status: {!Case.Status}
- Priority: {!Case.Priority}

You can view your ticket and add updates at any time by visiting:
https://your-site-url/support/ticket/{!Case.Id}

Expected Response Time:
- High Priority: Within 24 hours
- Medium Priority: Within 48 hours
- Low Priority: Within 5 business days

If you have any questions, please don't hesitate to contact us.

Best regards,
Technical Team
```

#### 2. Create Email Template: Ticket Updated

1. Create new template: `Ticket Updated`
2. Subject: `Update on your support ticket #[CaseNumber]`
3. Body: Include ticket details and status update information

#### 3. Create Email Template: Ticket Comment Added

1. Create new template: `Ticket Comment Added`
2. Subject: `New response on your support ticket #[CaseNumber]`
3. Body: Include comment content and ticket link

#### 4. Create Email Template: Ticket Resolved

1. Create new template: `Ticket Resolved`
2. Subject: `Your support ticket #[CaseNumber] has been resolved`
3. Body: Include resolution details

### Phase 7: Create Flow for Email Notifications

#### 1. Create Flow: Case Created Notification

1. Navigate to **Setup** → **Flows** → **New Flow**
2. Select **Record-Triggered Flow**
3. Configure:
   - **Object**: Case
   - **Trigger**: After Save
   - **Entry Conditions**: 
     - `{!$Record.Origin} equals "Web"`
   - **Optimize for**: Actions and Related Records
4. Add elements:
   - **Action**: Send Email Alert
   - **Email Alert**: Create new email alert
     - **Description**: `Notify member when ticket is created`
     - **Email Template**: Select "Ticket Created Confirmation"
     - **Recipient Type**: Related Contact
     - **Recipient**: `{!$Record.ContactId}`
5. **Save** and **Activate**

#### 2. Create Flow: Case Status Update Notification

1. Create new **Record-Triggered Flow**
2. Configure:
   - **Object**: Case
   - **Trigger**: After Save
   - **Entry Conditions**: 
     - `{!$Record.Origin} equals "Web"`
     - `{!$Record.PRIORVALUE(Status)} not equals {!$Record.Status}`
3. Add decision element:
   - **Outcome 1**: Status = "Resolved" or "Closed"
     - Action: Send Email Alert (Ticket Resolved template)
   - **Default Outcome**: 
     - Action: Send Email Alert (Ticket Updated template)
4. **Save** and **Activate**

#### 3. Create Process Builder: Case Comment Notification

Since Case Comment triggers are complex, use Process Builder:

1. Navigate to **Setup** → **Process Builder** → **New**
2. Configure:
   - **Name**: `Notify Member on Case Comment`
   - **API Name**: `Notify_Member_on_Case_Comment`
   - **Description**: `Send email notification when agent adds public comment`
3. **Object**: Case Comment
4. **Trigger**: A record changes
5. **Start Process**: Only when a record is created
6. **Criteria**: 
   - `[CaseComment].IsPublished equals True`
7. **Immediate Actions**:
   - **Action**: Send Email Alert
   - **Email Alert**: (Create new for "Ticket Comment Added" template)
   - **Recipient**: `[CaseComment].Parent.ContactId`
8. **Save** and **Activate**

> **Note**: You may need to create a custom field on Case to trigger updates when comments are added, or use a different automation approach.

### Phase 8: Configure Default Values (Optional)

#### 1. Create Validation Rules

1. Navigate to **Setup** → **Object Manager** → **Case** → **Validation Rules**
2. Click **New**
3. Create validation rule: **Required Fields on Create**
   - **Rule Name**: `Required_Fields_on_Create`
   - **Error Condition Formula**: 
     ```
     AND(
       ISBLANK(Subject),
       OR(ISBLANK(Description), LEN(Description) < 10)
     )
     ```
   - **Error Message**: `Please provide both a Subject and a Description (minimum 10 characters).`
   - **Error Location**: Subject

4. Create validation rule: **Contact Required for Member Submissions**
   - **Rule Name**: `Contact_Required_for_Member_Submissions`
   - **Error Condition Formula**: 
     ```
     AND(
       Origin = "Web",
       ISBLANK(ContactId)
     )
     ```
   - **Error Message**: `A Contact must be associated with this ticket. Please ensure you are logged in with a valid member account.`
   - **Error Location**: Contact

### Phase 9: Testing

#### 1. Test Member Ticket Submission

1. Log in as Experience Cloud member
2. Click "Support" dropdown in navigation menu
3. Select "Submit Ticket"
4. Navigate to Submit Ticket page
4. Fill out form:
   - Select ticket type
   - Enter subject
   - Enter description (at least 10 characters)
   - Optionally select priority
5. Click "Submit Ticket"
6. Verify:
   - ✅ Success message appears with Case Number
   - ✅ Ticket appears in "My Tickets" list
   - ✅ Confirmation email received
   - ✅ Ticket assigned to correct queue

#### 2. Test Member Ticket Viewing

1. Click "Support" dropdown in navigation menu
2. Select "My Tickets"
3. Navigate to My Tickets page
4. Verify:
   - ✅ All tickets for member are visible
   - ✅ Filters work correctly (Status: All/Open/Closed, Record Type)
   - ✅ Clicking ticket navigates to detail page
   - ✅ Ticket detail shows all information
   - ✅ Comments are visible (only published comments)
   - ✅ Date formatting displays correctly
   - ✅ Status and priority badges display with correct colors
   - ✅ Refresh button updates the ticket list

#### 3. Test Adding Comments

1. Open an open ticket (not Closed/Resolved)
2. Scroll to "Add Comment" section
3. Enter comment (minimum length validation should apply)
4. Click "Add Comment"
5. Verify:
   - ✅ Comment appears immediately after submission
   - ✅ Comment text is cleared after successful submission
   - ✅ Success toast notification appears
   - ✅ Email notification sent (if configured)
   - ✅ Comment is visible to member with correct formatting
   - ✅ Comment shows author name and timestamp
   - ✅ Adding comment to closed ticket is disabled
   - ✅ Add Comment button is disabled when comment field is empty

#### 4. Test Agent Workflows

1. Log in as technical team member
2. Navigate to Cases tab or Queue
3. Verify:
   - ✅ Can see all tickets in assigned queue
   - ✅ Can update ticket status
   - ✅ Can add internal comments
   - ✅ Can add public comments
   - ✅ Can resolve tickets

#### 5. Test Notifications

1. As agent, update ticket status
2. Verify:
   - ✅ Member receives email notification
3. As agent, add public comment
4. Verify:
   - ✅ Member receives email notification with comment content

### Phase 10: Production Deployment

1. **Deploy to Production**:
   ```bash
   sf project deploy start \
       --source-dir force-app/main/default \
       --target-org production-org-alias
   ```

2. **Configure Queues** in production (same as Phase 2)

3. **Assign Permission Sets** to profiles (same as Phase 3)

4. **Create Experience Cloud Pages** (same as Phase 5)

5. **Create Email Templates** (same as Phase 6)

6. **Create Flows** (same as Phase 7)

7. **Test in Production** (same as Phase 9)

8. **Communicate to Members**:
   - Send announcement email
   - Update help documentation
   - Add link to navigation

## Troubleshooting

### Members Cannot See Tickets

- Verify Permission Set is assigned to member profile
- Check Organization-Wide Default is set to Private
- Verify Case.ContactId is populated correctly
- Check sharing rules if using custom sharing

### Emails Not Sending

- Verify Email Deliverability settings
- Check Email Template is activated
- Verify recipient Contact has valid email address
- Review Email Alert configuration
- Check Flow debug logs

### Queue Assignment Not Working

- Verify queues exist with correct names:
  - "Technical Support Queue"
  - "Product Feedback Queue"
- Check record type developer names match expected values
- Review Apex debug logs for queue lookup errors

### Components Not Displaying

- Verify components are deployed
- Check Experience Builder component visibility settings
- Verify page is published
- Check browser console for JavaScript errors
- Verify permission set allows Case access

## Maintenance

### Regular Tasks

1. **Monitor Ticket Volume**: Review queue sizes weekly
2. **Review Resolution Times**: Track average resolution time
3. **Member Feedback**: Gather feedback on ticketing experience
4. **Email Deliverability**: Monitor bounce rates
5. **Component Performance**: Review load times

### Updates

- Keep Salesforce API version current
- Review new Experience Cloud features
- Update components as needed
- Add new record types as requirements evolve

## Support

For questions or issues with the ticketing system:
- Review technical architecture documentation
- Check debug logs for errors
- Contact technical team: webdev@spokanemountaineers.org

---

**Last Updated**: [Date]  
**Version**: 1.0

