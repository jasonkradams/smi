# Member Ticketing System: Technical Architecture

*Status: Planning Phase | Category: Salesforce Solutions*

## Executive Summary

This document provides comprehensive technical architecture for a member ticketing system that enables Experience Cloud members to submit technical issues, feature requests, account access problems, and general feedback directly to the technical team. The system leverages Salesforce's standard Case object with customizations, Lightning Web Components for member-facing interfaces, and automated notifications to keep members informed throughout the ticket lifecycle.

## Business Requirements

### Problem Statement

Currently, members of the Spokane Mountaineers can only submit feedback through word of mouth during club events, which means:
- Feedback is often lost or forgotten
- Members receive no confirmation their concerns were heard
- No systematic way to track and prioritize member issues
- Technical team lacks visibility into member pain points
- No audit trail of member interactions and resolutions

### Solution Goals

1. **Member Self-Service**: Enable members to submit tickets directly through Experience Cloud
2. **Visibility**: Provide members with visibility into their ticket status and history
3. **Organization**: Categorize tickets by type (Technical Bugs, Feature Requests, Account Access, General Feedback)
4. **Communication**: Automatically notify members when their tickets are updated or resolved
5. **Team Efficiency**: Provide tools for the technical team to efficiently manage and resolve tickets

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                  Experience Cloud Portal                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Ticket     │  │   Member     │  │   Ticket     │     │
│  │ Submission   │  │   Ticket     │  │   Detail     │     │
│  │    Form      │  │    List      │  │    View      │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │             │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │      Salesforce Case Object         │
          │                                     │
          │  ┌────────────┐  ┌────────────┐    │
          │  │   Record   │  │   Queues   │    │
          │  │   Types    │  │            │    │
          │  └────────────┘  └────────────┘    │
          └──────────────────┬──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │     Automation & Notifications      │
          │                                     │
          │  ┌────────────┐  ┌────────────┐    │
          │  │   Email    │  │   Flow     │    │
          │  │ Templates  │  │  Triggers  │    │
          │  └────────────┘  └────────────┘    │
          └──────────────────┬──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │      Technical Team Tools           │
          │                                     │
          │  ┌────────────┐  ┌────────────┐    │
          │  │   List     │  │ Dashboard  │    │
          │  │   Views    │  │  & Reports │    │
          │  └────────────┘  └────────────┘    │
          └─────────────────────────────────────┘
```

## Data Model

### Core Object: Case

The system uses the standard Salesforce **Case** object with the following customizations:

#### Record Types

1. **Technical Bug**
   - For website/application bugs and technical issues
   - Assigned to: Technical Support Queue
   - Priority options: High, Medium, Low
   - Status values: New, In Progress, Waiting for Member, Resolved, Closed

2. **Feature Request**
   - For enhancement requests and new feature ideas
   - Assigned to: Product Feedback Queue
   - Priority options: High, Medium, Low
   - Status values: New, Under Review, Planned, In Development, Completed, Declined

3. **Account Access**
   - For login issues, password resets, access problems
   - Assigned to: Technical Support Queue
   - Priority options: High, Medium, Low
   - Status values: New, In Progress, Waiting for Member, Resolved, Closed

4. **General Feedback**
   - For general comments, suggestions, non-technical feedback
   - Assigned to: Product Feedback Queue
   - Priority options: Medium, Low
   - Status values: New, Under Review, Acknowledged, Closed

#### Custom Fields

**Standard Fields Used:**
- `Case.ContactId` (Lookup to Contact) - Automatically populated with member's Contact
- `Case.Subject` (Text 255) - Ticket title/summary
- `Case.Description` (Long Text Area) - Detailed ticket description
- `Case.Priority` (Picklist) - Priority level
- `Case.Status` (Picklist) - Current ticket status
- `Case.Origin` (Picklist) - Set to "Web" for Experience Cloud submissions
- `Case.OwnerId` (Lookup to User/Queue) - Ticket owner (queue or user)

**Custom Fields (if needed):**
- `Case.Related_User__c` (Formula) - Formula field: `Contact.User_Lookup__c`
  - Displays the related User record from the Contact
  - Formula: `Contact.User_Lookup__c`
  - Purpose: Quick access to member's User record for technical team

#### Object Relationships

```
Case
├── Contact (Lookup) - Required, populated automatically
│   └── User (Lookup via Contact.User_Lookup__c) - Optional
├── Owner (User or Queue) - Assigned manually or via default
├── CreatedBy (User) - Member's User record (if available)
└── Case Comments (Master-Detail) - Standard Salesforce feature
```

### Supporting Objects

#### Contact Object
- Standard Salesforce Contact object
- Custom field: `Contact.User_Lookup__c` (already exists)
- Purpose: Links Contact to User for member identification

#### Queue Objects
- **Technical Support Queue**
  - Members: Technical team members
  - Used for: Technical Bug, Account Access tickets
  - Default assignment for urgent technical issues

- **Product Feedback Queue**
  - Members: Technical team members and product stakeholders
  - Used for: Feature Request, General Feedback tickets
  - Default assignment for enhancement requests

## Security & Sharing Model

### Experience Cloud Member Permissions

**Permission Set: "Member Ticket Access"**
- **Object Permissions:**
  - Case: Read (own records), Create
  - Case Comment: Read (own records), Create
  - Contact: Read (own record only)
  - User: Read (public fields only)

- **Field Permissions:**
  - Case: Read/Edit on all standard fields (Subject, Description, Priority, Status)
  - Case: No access to internal fields (Internal Comments, Resolution, etc.)
  - Contact: Read on Name, Email (own record only)

- **Sharing Rules:**
  - Cases are automatically shared with the Contact (member)
  - OWD for Cases: Private (members can only see their own)

**Profile Updates:**
- Experience Cloud Guest User Profile: No Case access (correct by default)
- Authenticated Member Profile: Inherits permissions from "Member Ticket Access" permission set

### Technical Team Permissions

**Permission Set: "Technical Team Agent"**
- **Object Permissions:**
  - Case: Full access (all records)
  - Case Comment: Full access
  - Contact: Read (all)
  - Queue: Full access

- **Field Permissions:**
  - Case: Full access to all fields including internal comments
  - Can see and manage all tickets regardless of owner

**Additional Considerations:**
- Technical team members should be added to both queues
- Queue members can see and manage tickets in their queues
- Manual assignment to queues (no automatic assignment rules)

## User Flows

### Member Flow: Submitting a Ticket

```
1. Member logs into Experience Cloud
   ↓
2. Clicks "Support" dropdown in navigation menu
   ↓
3. Selects "Submit Ticket" option
   ↓
4. Navigates to "/support/submit-ticket" page
   ↓
5. Ticket Submission Form loads automatically:
   - Ticket Type (Record Type) - Required
     * Technical Bug
     * Feature Request
     * Account Access
     * General Feedback
   - Subject - Required
   - Description - Required
   - Priority - Optional (defaults based on type)
   ↓
5. Member fills form and clicks "Submit"
   ↓
6. Validation:
   - Verify required fields are populated
   - Verify member has Contact record
   - Verify member is authenticated
   ↓
7. Create Case record:
   - ContactId: Member's Contact
   - OwnerId: Appropriate Queue (based on Record Type)
   - Origin: "Web"
   - Subject, Description, Priority from form
   ↓
8. Send confirmation email to member
   ↓
9. Display success message with Case Number
   ↓
10. Redirect to "/support/my-tickets" page
```

### Member Flow: Viewing Tickets

```
1. Member logs into Experience Cloud
   ↓
2. Clicks "Support" dropdown in navigation menu
   ↓
3. Selects "My Tickets" option
   ↓
4. Navigates to "/support/my-tickets" page
   ↓
5. Member Ticket List Component loads
   - Queries Cases where ContactId = Current User's Contact
   - Shows: Case Number, Subject, Type, Status, Priority, Created Date
   ↓
4. Member clicks on a ticket
   ↓
5. Ticket Detail View loads:
   - Full ticket details
   - Status history
   - Comments/Updates
   - Reply/Add Comment section (if open)
   ↓
6. Member can:
   - View ticket details
   - Add comments (if status allows)
   - See agent responses
```

### Agent Flow: Managing Tickets

```
1. Agent logs into Salesforce
   ↓
2. Navigates to "Cases" tab or Queue
   ↓
3. Views ticket list (All Tickets or Queue-specific)
   ↓
4. Clicks on a ticket
   ↓
5. Ticket Detail Page loads with:
   - Member information (Contact, User if available)
   - Full ticket details
   - Internal comments section
   - Status update options
   - Resolution field (when closing)
   ↓
6. Agent can:
   - Update Status
   - Add Internal Comments
   - Add Public Comments (visible to member)
   - Assign to another user or queue
   - Set Priority
   - Resolve/Close ticket
   ↓
7. When agent adds public comment or updates status:
   - Flow triggers email notification to member
   - Member sees update in Experience Cloud
```

## Component Specifications

### Lightning Web Component: ticketSubmissionForm

**Purpose**: Allow members to create new support tickets

**Location**: `/force-app/main/default/lwc/ticketSubmissionForm/`

**Properties:**
- `@api recordId` - Not used (form-based component)

**Fields:**
- Record Type (Picklist) - Required
  - Technical Bug
  - Feature Request
  - Account Access
  - General Feedback
- Subject (Text Input) - Required, max 255 characters
- Description (Rich Text/Textarea) - Required
- Priority (Picklist) - Optional, defaults based on record type
  - High, Medium, Low

**Apex Methods:**
- `TicketSubmissionHelper.getContactForUser()` - Get Contact for current Experience Cloud user
- `TicketSubmissionHelper.createCase()` - Create Case record with validation

**Validation:**
- All required fields must be populated
- User must be authenticated
- User must have associated Contact record
- Subject max 255 characters

**Success Behavior:**
- Display success toast with Case Number
- Clear form
- Redirect to "/support/my-tickets" page

**Error Handling:**
- Display error messages in toast
- Maintain form data for retry
- Log errors for debugging

### Lightning Web Component: memberTicketList

**Purpose**: Display list of member's tickets with filtering and sorting

**Location**: `/force-app/main/default/lwc/memberTicketList/`

**Properties:**
- None (standalone component)

**Display Fields:**
- Case Number (link to detail)
- Subject
- Record Type (Badge/Icon)
- Status (Badge)
- Priority (Badge)
- Created Date
- Last Modified Date

**Features:**
- Filter by Status (All, Open, Closed)
- Filter by Record Type
- Sort by Created Date (newest first) or Last Modified
- Pagination (20 per page)
- Real-time updates (refresh button)

**Apex Methods:**
- `TicketQueryHelper.getMyTickets()` - Query Cases for current user's Contact

**Wire Service:**
- Uses `@wire` for reactive data loading
- Automatically refreshes when new tickets created

### Lightning Web Component: ticketDetail

**Purpose**: Display detailed ticket view with comments and update capability

**Location**: `/force-app/main/default/lwc/ticketDetail/`

**Properties:**
- `@api recordId` - Case ID (required)

**Display Sections:**
1. **Ticket Header**
   - Case Number
   - Subject
   - Record Type (Badge)
   - Status (Badge)
   - Priority (Badge)
   - Created Date
   - Last Modified Date

2. **Ticket Details**
   - Description (full text)
   - Related Contact (link if visible)
   - Owner (Queue or User name)

3. **Comments Section**
   - Chronological list of Case Comments
   - Public comments (visible to member)
   - Comment author and timestamp
   - Most recent first

4. **Add Comment** (if ticket is open)
   - Text area for new comment
   - Submit button
   - Character limit indicator

**Apex Methods:**
- `TicketQueryHelper.getTicketDetails()` - Get Case with related data
- `TicketQueryHelper.getTicketComments()` - Get Case Comments
- `TicketSubmissionHelper.addComment()` - Add new public comment

**Permission Checks:**
- Verify member owns the ticket (Case.ContactId = User's Contact)
- Disable edit if ticket is closed/resolved

**Real-time Updates:**
- Refresh button to reload latest comments
- Auto-refresh every 30 seconds (optional, configurable)

## Automation & Workflows

### Flow: Case Creation Notification

**Trigger**: Case Created (After Save)

**Purpose**: Send confirmation email to member when ticket is created

**Process:**
1. Check if Case.Origin = "Web"
2. Get Case Contact's Email
3. Load email template: "Ticket Created Confirmation"
4. Populate template with:
   - Case Number
   - Subject
   - Record Type
   - Expected response time
5. Send email via Email Alert

**Email Template: "Ticket Created Confirmation"**
- Subject: "Your support ticket #[CaseNumber] has been received"
- Body includes:
  - Greeting with Contact name
  - Case details (number, subject, type)
  - Link to view ticket in Experience Cloud
  - Expected response time based on priority
  - Support contact information

### Flow: Case Status Update Notification

**Trigger**: Case Updated (After Save), when Status or Owner changes

**Purpose**: Notify member when ticket is updated by agent

**Process:**
1. Check if Case status changed (prior value != current value)
2. Check if Case has public comment added (via Case Comment trigger)
3. Get Case Contact's Email
4. Load appropriate email template based on status:
   - "Ticket Updated" - for status changes
   - "Ticket Comment Added" - for new comments
   - "Ticket Resolved" - for resolved/closed status
5. Populate template with:
   - Case Number
   - Status change details
   - Agent comment (if applicable)
   - Link to view ticket
6. Send email via Email Alert

**Email Templates:**
1. **"Ticket Updated"**
   - Subject: "Update on your support ticket #[CaseNumber]"
   - Body: Status change notification with ticket link

2. **"Ticket Comment Added"**
   - Subject: "New response on your support ticket #[CaseNumber]"
   - Body: Agent comment preview and ticket link

3. **"Ticket Resolved"**
   - Subject: "Your support ticket #[CaseNumber] has been resolved"
   - Body: Resolution details and satisfaction survey link (optional)

### Flow: Case Comment Trigger (Helper)

**Purpose**: Detect when public comments are added to trigger notifications

**Implementation:**
- Use Case Comment trigger or Process Builder
- When Case Comment is created/updated:
  - Check if IsPublished = true (public comment)
  - Update Case.Last_Public_Comment_Date__c (custom field) to trigger Case update
  - This triggers the Case Status Update Notification flow

**Alternative**: Direct Case Comment trigger to call notification flow

### Validation Rules

**Case Validation Rule: "Required Fields on Create"**
- Error Condition: AND(
  - ISBLANK(Subject),
  - OR(ISBLANK(Description), LEN(Description) < 10)
)
- Error Message: "Please provide both a Subject and a Description (minimum 10 characters)."

**Case Validation Rule: "Contact Required for Member Submissions"**
- Error Condition: AND(
  - Origin = "Web",
  - ISBLANK(ContactId)
)
- Error Message: "A Contact must be associated with this ticket. Please ensure you are logged in with a valid member account."

## Queue Structure

### Technical Support Queue

**Purpose**: Handle technical bugs and account access issues

**Members:**
- Technical team members
- System administrators
- Support staff

**Default Assignment:**
- Technical Bug record types
- Account Access record types

**Queue Configuration:**
- Email notification: Yes (new case assigned)
- Auto-assignment: No (manual assignment only)

### Product Feedback Queue

**Purpose**: Handle feature requests and general feedback

**Members:**
- Technical team members
- Product managers
- Stakeholders

**Default Assignment:**
- Feature Request record types
- General Feedback record types

**Queue Configuration:**
- Email notification: Yes (new case assigned)
- Auto-assignment: No (manual assignment only)

**Note**: Assignment to queues is manual. When a Case is created, the default queue is set based on Record Type, but agents can reassign as needed.

## Integration Points

### Experience Cloud Integration

**Page Configuration:**
- **Submit Ticket Page**: `/support/submit-ticket`
  - Components: ticketSubmissionForm (configured to show form on load)

- **My Tickets Page**: `/support/my-tickets`
  - Components: memberTicketList

- **FAQ Page**: `/support/faq`
  - Components: Rich Text or CMS Content with FAQ information

- **Ticket Detail Page**: `/support/ticket/:caseId`
  - Components: ticketDetail
  - URL parameter: Case ID (15 or 18 character)

**Navigation:**
- **Support** dropdown menu in Experience Cloud navigation:
  - **Submit Ticket** → `/support/submit-ticket`
  - **My Tickets** → `/support/my-tickets`
  - **FAQ** → `/support/faq`
- Visible to authenticated members only

**Site Configuration:**
- Ensure Case object is enabled for Experience Cloud
- Ensure Case object has proper sharing settings
- Ensure member profiles have appropriate permissions

### Email Integration

**Email Templates:**
- All templates use HTML format
- Include Experience Cloud branding (logo, colors)
- Include unsubscribe link (compliance)
- Mobile-responsive design

**Email Deliverability:**
- Ensure Salesforce Email Deliverability is configured
- Test email delivery to common email providers
- Monitor bounce rates and spam reports

## Reporting & Dashboards

### Member-Facing Reports (Future)

**Not included in initial scope but can be added:**
- Ticket submission trends
- Average resolution time
- Most common ticket types

### Agent Dashboards

**"Ticket Management Overview" Dashboard:**

1. **Ticket Volume Metrics**
   - Total Open Tickets (key metric)
   - Tickets by Record Type (chart)
   - Tickets by Priority (chart)
   - Tickets by Queue (chart)

2. **Ticket Age Analysis**
   - Average Age of Open Tickets
   - Tickets Older Than 7 Days
   - Tickets Older Than 14 Days
   - Oldest Open Ticket

3. **Queue Performance**
   - Tickets in Technical Support Queue
   - Tickets in Product Feedback Queue
   - Unassigned Tickets

4. **Resolution Metrics**
   - Tickets Resolved This Week
   - Average Resolution Time (days)
   - Resolution Rate by Type

**Report Requirements:**
- Build standard Salesforce Reports on Case object
- Filter by appropriate criteria
- Create Dashboard with report components
- Refresh on page load

## Testing Strategy

### Unit Testing

**Apex Classes:**
- `TicketSubmissionHelper`: Test case creation, validation, error handling
- `TicketQueryHelper`: Test query logic, filtering, permission checks
- Target: 95%+ code coverage

**Lightning Web Components:**
- Component rendering
- User interaction flows
- Error handling
- Data loading states

### Integration Testing

**Member Flows:**
1. Submit new ticket (all record types)
2. View ticket list
3. View ticket detail
4. Add comment to open ticket
5. Verify email notifications received

**Agent Flows:**
1. View tickets in queue
2. Update ticket status
3. Add internal comment
4. Add public comment
5. Resolve ticket
6. Verify member receives notification

**Error Scenarios:**
1. Submit ticket without required fields
2. Submit ticket while logged out
3. Access ticket belonging to another member
4. Add comment to closed ticket

### User Acceptance Testing

**Test Cases:**
- [ ] Member can successfully submit all ticket types
- [ ] Member receives confirmation email
- [ ] Member can view their tickets
- [ ] Member receives update notifications
- [ ] Agent can manage tickets in queues
- [ ] Email notifications work correctly
- [ ] Mobile experience is functional

## Deployment Strategy

### Phase 0: Sandbox Setup
1. Create/refresh sandbox environment
2. Deploy base configuration (record types, fields, queues)
3. Set up test data

### Phase 1: Foundation
1. Deploy Case object customizations
2. Set up queues
3. Configure permissions and sharing
4. Test in sandbox

### Phase 2: Components
1. Deploy Lightning Web Components
2. Configure Experience Cloud pages
3. Test member flows in sandbox

### Phase 3: Automation
1. Deploy Flows for notifications
2. Create email templates
3. Test email delivery in sandbox

### Phase 4: Agent Tools
1. Create list views
2. Build dashboard
3. Test agent workflows

### Phase 5: Production Deployment
1. Deploy all components to production
2. Configure production-specific settings
3. Communicate to members
4. Monitor initial ticket volume

## Maintenance & Monitoring

### Ongoing Tasks

1. **Monitor Ticket Volume**
   - Review queue sizes weekly
   - Identify bottlenecks
   - Adjust queue membership as needed

2. **Monitor Email Deliverability**
   - Check bounce rates
   - Review spam reports
   - Update email templates if needed

3. **Review Resolution Times**
   - Track average resolution time
   - Identify ticket types that take longer
   - Adjust priorities as needed

4. **Member Feedback**
   - Gather feedback on ticketing experience
   - Update UI/UX based on feedback
   - Improve documentation

### Metrics to Track

- Total tickets created per month
- Average resolution time
- Tickets by type (distribution)
- Member satisfaction (future: survey)
- Email delivery rate
- Component load times

## Future Enhancements (Out of Scope)

**Not included in initial implementation but can be added later:**
1. Email-to-Case integration (email submissions)
2. Knowledge Base integration (suggested articles)
3. SLA tracking and escalation rules
4. Member satisfaction surveys
5. Automated ticket routing based on keywords
6. Integration with external ticketing systems
7. Mobile app support
8. Live chat integration
9. Ticket templates for common issues
10. Advanced reporting and analytics

## Dependencies

### Salesforce Features Required
- Experience Cloud enabled
- Case object enabled
- Email-to-Case (optional, not in initial scope)
- Flows enabled
- Process Builder (if used)
- Email Templates feature

### External Dependencies
- None (all native Salesforce)

### Data Dependencies
- Contact records for all Experience Cloud members
- Contact.User_Lookup__c field must be populated (already exists)
- User records for members with Experience Cloud access

## Risk Assessment

### Technical Risks

1. **Email Deliverability**
   - Risk: Emails not reaching members
   - Mitigation: Configure Salesforce email settings, test thoroughly, monitor bounce rates

2. **Performance with High Volume**
   - Risk: Component slow with many tickets
   - Mitigation: Implement pagination, optimize SOQL queries, use indexes

3. **Permission Issues**
   - Risk: Members unable to access tickets
   - Mitigation: Thorough testing of permission sets, clear error messages

### Business Risks

1. **High Ticket Volume**
   - Risk: Overwhelming technical team
   - Mitigation: Set expectations, prioritize queue management, consider SLAs

2. **Member Adoption**
   - Risk: Members don't use the system
   - Mitigation: Clear communication, easy-to-use interface, training materials

## Success Criteria

### Phase 0 (Documentation) - COMPLETE
- [x] Comprehensive technical documentation created
- [x] Architecture diagrams completed
- [x] All user flows documented
- [x] Component specifications defined

### Phase 1 (Foundation)
- [ ] Case record types created and tested
- [ ] Queues configured and tested
- [ ] Permissions and sharing rules verified
- [ ] Documentation updated with actual implementation

### Phase 2 (Member Interface)
- [ ] Ticket submission component deployed and tested
- [ ] Member ticket list component deployed and tested
- [ ] Ticket detail component deployed and tested
- [ ] Member flows verified end-to-end

### Phase 3 (Automation)
- [ ] Email templates created and tested
- [ ] Notification flows deployed and tested
- [ ] Email delivery verified

### Phase 4 (Agent Tools)
- [ ] Agent list views created
- [ ] Dashboard built and tested
- [ ] Agent workflows verified

### Phase 5 (Testing & Documentation)
- [ ] All test cases passed
- [ ] User documentation created
- [ ] Deployment guide completed
- [ ] Production deployment successful

## Security Analysis

For a comprehensive security analysis including SOQL injection prevention, OWASP Top 10 compliance, and access control mechanisms, see [Member Ticketing System Security Analysis](../security/member-ticketing-system-security-analysis.md).

**Quick Summary**:
- ✅ **SOQL Injection Protected**: All queries use bind variables
- ✅ **Access Control**: Multiple layers (with sharing, ContactId filtering, explicit checks)
- ✅ **OWASP Top 10 Compliant**: Protected against injection and broken access control
- ✅ **Input Validation**: All inputs validated before processing

## Appendices

### Appendix A: Field Reference

| Field Name | Type | Required | Purpose |
|------------|------|----------|---------|
| Case.ContactId | Lookup | Yes | Links ticket to member's Contact |
| Case.Subject | Text(255) | Yes | Ticket title |
| Case.Description | Long Text | Yes | Ticket details |
| Case.Priority | Picklist | No | Priority level |
| Case.Status | Picklist | Yes | Current status |
| Case.Origin | Picklist | Yes | Submission source (Web) |
| Case.OwnerId | Lookup | Yes | Queue or User |
| Case.RecordTypeId | Picklist | Yes | Ticket type |
| Case.Related_User__c | Formula | No | Derived from Contact.User_Lookup__c |

### Appendix B: Record Type Values

**Technical Bug:**
- Priority: High, Medium, Low
- Status: New, In Progress, Waiting for Member, Resolved, Closed

**Feature Request:**
- Priority: High, Medium, Low
- Status: New, Under Review, Planned, In Development, Completed, Declined

**Account Access:**
- Priority: High, Medium, Low
- Status: New, In Progress, Waiting for Member, Resolved, Closed

**General Feedback:**
- Priority: Medium, Low
- Status: New, Under Review, Acknowledged, Closed

### Appendix C: Email Template Placeholders

Available merge fields for email templates:
- `{!Case.CaseNumber}` - Case number
- `{!Case.Subject}` - Ticket subject
- `{!Case.Description}` - Ticket description
- `{!Case.Type}` - Record type name
- `{!Case.Status}` - Current status
- `{!Case.Contact.Name}` - Member name
- `{!Case.Contact.Email}` - Member email
- `{!Case.Owner.Name}` - Queue/Agent name

---

**Document Version:** 1.0  
**Last Updated:** [Date]  
**Status:** Planning Complete - Ready for Implementation  
**Next Steps:** Phase 0 - Sandbox Environment Setup

