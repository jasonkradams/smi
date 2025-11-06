# Solving Event Participant Privacy in Experience Cloud

*Published: November 5, 2025 | Category: Salesforce Solutions*

## The Privacy Puzzle We Faced

Picture this: A community member is browsing our upcoming Events in Experience Cloud, curious about who else is attending. They click on an Event Participant's name, expecting to see a public profile. Instead, they land on a full Contact record - complete with phone numbers, addresses, and other information that should remain private.

This wasn't just a theoretical concern. As the Spokane Mountaineers grew, we realized our Event Participant links were creating an unintended privacy loophole. The core issue was architectural: Salesforce's Event data model requires Event Participants to relate to Contact records, not User records. But Contact visibility isn't governed by User privacy settings, creating a disconnect between what we wanted (privacy-respecting profile views) and what we had (unrestricted Contact access).

## Our Approach: Bridge, Don't Replace

Instead of fighting Salesforce's data model, we decided to work with it. The solution? Build a smart bridge between Contacts and Users, then use that bridge to make intelligent routing decisions.

Here's how we tackled it step by step:

### 1. Creating the Connection Bridge

First, we extended the Contact object with a custom lookup field:

```xml
<!-- Contact.User_Lookup__c -->
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>User_Lookup__c</fullName>
    <label>Related User</label>
    <referenceTo>User</referenceTo>
    <type>Lookup</type>
</CustomField>
```

This simple field creates a 1:1 relationship where possible, linking Contacts to their corresponding User records. It's the foundation of our entire solution.

### 2. Automating the Synchronization

Manual data entry wasn't an option - we needed automation. We implemented a three-layered sync strategy:

**Real-time Sync**: A record-triggered Flow that automatically updates the Contact lookup when Users are created or modified. This catches new users and any changes to existing ones.

**Batch Backfill**: For our existing data, we created a batch Apex class that processes contacts in batches of 200, matching Contacts to Users based on a prioritized approach:
1. **Email Match** (most reliable): `Contact.Email = User.Email`
2. **FederationIdentifier Match**: `Contact.Email` (transformed) = `User.FederationIdentifier`
   - Transformation: Replace `@` with `_` and append `@spokanemountaineers.org`
   - Example: `jason@example.com` → `jason_example.com@spokanemountaineers.org`
3. **Username Match**: `Contact.Email + '.smi' = User.Username`
   - Example: `jason@example.com` → `jason@example.com.smi`

This prioritized approach ensures we match the most reliable identifier first, avoiding duplicate email matches while handling various User naming conventions.

**Manual Sync**: Apex methods available for administrators to manually trigger syncs when needed (via Anonymous Apex or custom automation).

### 3. The Smart Related List Component

Since Event Participants in our org use the custom `Event_Participant__c` object (which links to `Event_Registration__c`), we created a custom Lightning Web Component that replaces the standard related list:

- **Custom Related List**: `eventParticipantRelatedList` component that queries `Event_Participant__c` records
- **Smart Click Handling**: Participants with linked Users redirect to User profiles, others show plain text
- **Rich Display**: Shows participant Contact name and response information
- **Graceful Degradation**: Handles missing User relationships elegantly
- **Visual Consistency**: Styled to match Salesforce standard related list appearance

The component checks each participant's `Contact.User_Lookup__c` field and creates conditional links:
- If a related User exists → Create a clickable link to their profile page (`/s/profile/{UserId}`)
- If no User exists → Show plain text (no link, just the name)

### 4. Enhanced User Experience

We built a Lightning Web Component that handles the redirect gracefully:

- Shows a loading state while checking for User profile availability
- Displays participant names with proper styling matching Salesforce standards
- Respects Experience Cloud visibility rules automatically
- Provides smooth navigation without jarring page reloads
- Matches the visual appearance of standard Salesforce related lists

## Technical Deep Dive: What We Built

### Custom Fields
- **Contact.User_Lookup__c** - The bridge field linking Contacts to Users (Lookup relationship)

### Lightning Web Components
- **eventParticipantRelatedList** - Custom related list that replaces standard Event Participants list with smart redirect functionality
  - Queries `Event_Participant__c` records for a given `Event_Registration__c`
  - Displays Contact names with conditional links to User profiles
  - Styled to match Salesforce standard related list appearance

### Flows
- **Sync_User_to_Contact** - Manual sync operations for administrators
- **User_to_Contact_Sync_Trigger** - Automatic real-time sync when Users change (Before Save trigger)

### Apex Classes
- **EventParticipantRedirectHelper** - Core business logic and utility methods
  - `getEventParticipants(String eventId)` - Retrieves participants for an Event or Event_Registration__c
  - `bulkSyncContactsToUsers(List<String> contactIds)` - Efficient bulk sync method (2 SOQL queries total)
  - `syncContactToUser(String contactId)` - Single contact sync method
- **ContactUserSyncBatch** - Efficient batch processing for existing data (processes 200 records per batch)

## Deployment Strategy: Minimal Disruption

We rolled this out carefully to avoid breaking anything:

1. **Deploy metadata** - All custom fields, classes, and components
2. **Run batch sync** - Backfill existing Contact-User relationships (achieved 99.14% sync rate)
3. **Update layouts** - Replace standard related list with our custom component
4. **Test thoroughly** - Verify both linked and unlinked scenarios work perfectly

## The Results: Privacy Preserved, Experience Enhanced

**Privacy Protection**: Community users now see User profile pages that respect privacy settings instead of unrestricted Contact records.

**Seamless Experience**: The redirect is completely transparent - users click a name and get the appropriate view based on data availability.

**Data Integrity**: We maintained Salesforce's standard Event data model while adding the necessary intelligence.

**Scalability**: The batch processing and automated sync ensure this works as our organization continues to grow. Our initial sync processed 1,732 out of 1,747 contacts (99.14% success rate).

**Performance**: The bulk sync method uses only 2-3 SOQL queries regardless of contact count, making it highly efficient for large-scale operations.

## Lessons from the Trenches

**Think Beyond the Obvious**: Initially, we considered overriding the standard related list entirely. But a custom LWC approach was cleaner, more maintainable, and less disruptive.

**Multiple Sync Strategies**: Real-time sync is great for new data, but batch processing is essential for existing records. You need both.

**Prioritized Matching**: Using a prioritized matching approach (Email → FederationIdentifier → Username) ensures we match the most reliable identifier first while handling various User naming conventions.

**Graceful Degradation**: Not every Contact will have a corresponding User. The solution handles this elegantly with plain text display rather than broken links.

**Test Edge Cases**: We discovered scenarios where Users exist but aren't community-enabled, requiring additional validation in our logic.

## What's Next?

We're already thinking about enhancements:

1. **Platform Events** for real-time sync across multiple systems
2. **Enhanced Matching** algorithms for Contact-User relationships
3. **Audit Trail** to track sync history and changes over time
4. **Admin Dashboard** for monitoring sync status and statistics

## The Takeaway

This solution shows how thoughtful Salesforce architecture can solve complex privacy and user experience challenges. By extending the standard data model rather than replacing it, we achieved our goals while maintaining system integrity and future compatibility.

The approach balances technical elegance with practical considerations, providing a robust solution that scales with our organization's needs while keeping our members' privacy intact.

---

**Technical Implementation**: All code and metadata for this solution is available in the SMI repository under `force-app/main/default/`. See below for deployment instructions.

---

## Implementation Guide: Deploying the Solution

Here's everything you need to deploy this privacy-enhancing solution to your own org:

### Custom Fields We Created

#### Contact.User_Lookup__c
- **Type**: Lookup (User)
- **Purpose**: The bridge field linking Contacts to Users
- **Location**: `/objects/Contact/fields/User_Lookup__c.field-meta.xml`

### Flows for Automation

#### Sync_User_to_Contact
- **Type**: Autolaunched Flow
- **Purpose**: Utility Flow for syncing a Contact to its matching User record
- **Input**: `recordId` (Contact ID)
- **Note**: This Flow exists but is not currently configured as a button or action on Contact records. For manual sync, use the Apex methods `syncContactToUser()` or `bulkSyncContactsToUsers()` via Anonymous Apex.
- **Location**: `/flows/Sync_User_to_Contact.flow-meta.xml`

#### User_to_Contact_Sync_Trigger
- **Type**: Record-Triggered Flow (User, Before Save)
- **Purpose**: Automatically syncs User to Contact when Users are created/updated
- **Location**: `/flows/User_to_Contact_Sync_Trigger.flow-meta.xml`

### Apex Classes for Core Logic

#### EventParticipantRedirectHelper
- **Purpose**: Provides methods for redirect logic and batch sync operations
- **Key Methods**:
  - `getEventParticipants(String eventId)` - Returns list of participants for an Event or Event_Registration__c
  - `bulkSyncContactsToUsers(List<String> contactIds)` - **Recommended**: Efficient bulk sync method (2-3 SOQL queries total)
  - `syncContactToUser(String contactId)` - Single contact sync method (legacy, use bulk method for multiple contacts)
- **Performance**: The `bulkSyncContactsToUsers` method reduces SOQL queries from ~3 per contact to just 2-3 total queries regardless of contact count
- **Location**: `/classes/EventParticipantRedirectHelper.cls`

#### ContactUserSyncBatch
- **Purpose**: Batch job to backfill existing Contacts with User lookups
- **Capacity**: Processes 200 records per batch execution (up to 50,000 contacts per batch job)
- **Matching Logic**: Prioritized approach:
  1. `Contact.Email = User.Email` (most reliable)
  2. `Contact.Email` (transformed) = `User.FederationIdentifier` (replace `@` with `_`, append `@spokanemountaineers.org`)
  3. `Contact.Email + '.smi' = User.Username` (common pattern)
- **Location**: `/classes/ContactUserSyncBatch.cls`

### Lightning Web Component

#### eventParticipantRelatedList
- **Purpose**: Custom related list component for Event Participants in Experience Cloud
- **Features**: 
  - Queries `Event_Participant__c` records for `Event_Registration__c`
  - Displays Contact names with conditional links to User profiles
  - Styled to match Salesforce standard related list appearance
  - Handles loading states and errors gracefully
- **Location**: `/lwc/eventParticipantRelatedList/`

## Step-by-Step Deployment

### 1. Deploy Custom Fields

```bash
# Deploy Contact custom field
sf project deploy start \
    --source-dir force-app/main/default/objects/Contact/fields/User_Lookup__c.field-meta.xml \
    --target-org your-org-alias
```

### 2. Deploy Apex Classes

```bash
# Deploy Apex classes with tests
sf project deploy start \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelper.cls \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelperTest.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatch.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatchTest.cls \
    --test-level RunSpecifiedTests \
    --tests EventParticipantRedirectHelperTest \
    --tests ContactUserSyncBatchTest \
    --target-org your-org-alias
```

### 3. Deploy Flows

```bash
sf project deploy start \
    --source-dir force-app/main/default/flows/Sync_User_to_Contact.flow-meta.xml \
    --source-dir force-app/main/default/flows/User_to_Contact_Sync_Trigger.flow-meta.xml \
    --target-org your-org-alias
```

### 4. Deploy Lightning Web Components

```bash
sf project deploy start \
    --source-dir force-app/main/default/lwc/eventParticipantRelatedList \
    --target-org your-org-alias
```

### 5. Alternative: Deploy All Components at Once

```bash
# Deploy all Event Participant Redirect components at once
sf project deploy start \
    --source-dir force-app/main/default/classes \
    --source-dir force-app/main/default/flows \
    --source-dir force-app/main/default/lwc \
    --source-dir force-app/main/default/objects \
    --test-level RunSpecifiedTests \
    --tests EventParticipantRedirectHelperTest \
    --tests ContactUserSyncBatchTest \
    --target-org your-org-alias
```

## Post-Deployment Setup

### 1. Run the Backfill Batch

Execute this in Developer Console or Anonymous Apex to sync existing data:

```java
// Run the batch to sync existing Contacts
Database.executeBatch(new ContactUserSyncBatch(), 200);
```

The batch job will:
- Process up to 50,000 contacts in batches of 200
- Use prioritized matching to link Contacts to Users
- Send a completion email with statistics

**Expected Results**: In our org, we achieved a 99.14% sync rate (1,732 out of 1,747 contacts successfully synced).

### 2. Update Event Page Layout

1. Navigate to Experience Cloud Builder
2. Edit the Event Registration page layout
3. Remove the standard Event Participants related list (if present)
4. Add the custom `eventParticipantRelatedList` component
5. Configure the component to show on Event Registration records
6. Save and publish the layout

### 3. Test Everything

1. Create a test Event Registration with multiple participants
2. Verify some participants have linked User accounts
3. Test clicking participant names in Experience Cloud
4. Confirm redirects work correctly for both linked and unlinked participants
5. Verify the component styling matches standard Salesforce related lists

## Bulk Sync Operations

### Efficient Bulk Sync Method

We've implemented a high-performance bulk sync method that dramatically reduces SOQL query usage:

**Performance Comparison:**
- **Legacy Method**: ~3 SOQL queries per contact
- **New Bulk Method**: Only 2-3 SOQL queries total regardless of contact count
- **Efficiency Gain**: 1,000 contacts = 3,000 queries → 3 queries (99.9% reduction!)

### Bulk Sync Examples

#### 1. Sync Specific Contacts by ID

```java
// Sync specific contacts by ID (most efficient)
List<String> contactIds = new List<String>{
    '0031N00001K1hLJQAZ',  // Contact 1
    '003Um00000jXt3pIAC',  // Contact 2
    '0032G00002sd32kQAA'   // Contact 3
};

List<EventParticipantRedirectHelper.SyncResult> results = 
    EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);

// Check results
for (EventParticipantRedirectHelper.SyncResult result : results) {
    System.debug('Contact ' + result.contactId + ' sync result: ' + result.success);
}
```

#### 2. Sync Contacts in Batches

```java
// Sync contacts in batches of 50 (optimal for governor limits)
List<Contact> contactsToSync = [
    SELECT Id, Name, Email, User_Lookup__c 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL
    ORDER BY CreatedDate
    LIMIT 400
];

Integer totalContacts = contactsToSync.size();
System.debug('Found ' + totalContacts + ' contacts to sync');

Integer successCount = 0;
Integer failureCount = 0;
Integer batchSize = 50;
List<String> currentBatch = new List<String>();

for (Integer i = 0; i < contactsToSync.size(); i++) {
    Contact contact = contactsToSync[i];
    currentBatch.add(contact.Id);
    
    if (currentBatch.size() >= batchSize || i == contactsToSync.size() - 1) {
        System.debug('Processing batch of ' + currentBatch.size() + ' contacts');
        
        List<EventParticipantRedirectHelper.SyncResult> batchResults = 
            EventParticipantRedirectHelper.bulkSyncContactsToUsers(currentBatch);
        
        for (EventParticipantRedirectHelper.SyncResult result : batchResults) {
            if (result.success) {
                successCount++;
            } else {
                failureCount++;
            }
        }
        
        currentBatch.clear();
    }
}

System.debug('Sync completed: ' + successCount + ' successful, ' + failureCount + ' failed');
System.debug('SOQL queries used: ' + Limits.getQueries() + '/' + Limits.getLimitQueries());
```

#### 3. Sync All Event Participants for a Specific Event

```java
// Sync all participants for a specific Event_Registration__c
String eventRegistrationId = 'a122G000008VdzJQAS'; // Replace with your Event_Registration__c ID

// Get all Event_Participant__c records for this Event_Registration__c
List<Event_Participant__c> participants = [
    SELECT Contact__c 
    FROM Event_Participant__c 
    WHERE Event_Registration__c = :eventRegistrationId
    AND Contact__c != null
];

// Extract Contact IDs
List<String> contactIds = new List<String>();
for (Event_Participant__c participant : participants) {
    contactIds.add(participant.Contact__c);
}

if (!contactIds.isEmpty()) {
    System.debug('Syncing ' + contactIds.size() + ' Event participants...');
    
    List<EventParticipantRedirectHelper.SyncResult> results = 
        EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);
    
    Integer successCount = 0;
    for (EventParticipantRedirectHelper.SyncResult result : results) {
        if (result.success) successCount++;
    }
    
    System.debug('Event participant sync completed: ' + successCount + '/' + results.size() + ' successful');
}
```

### Performance Monitoring

The bulk sync method includes built-in performance monitoring:

```java
// Monitor SOQL usage during bulk sync
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('SOQL queries remaining: ' + (Limits.getLimitQueries() - Limits.getQueries()));
```

**Expected Results:**
- Small batches (50 contacts): ~3 SOQL queries total
- Large batches (1,000+ contacts): ~3 SOQL queries total
- Query limit usage: <5% regardless of contact count

## Matching Logic Details

### Prioritized Matching Strategy

The sync process uses a three-tier matching approach:

1. **Email Match** (Highest Priority)
   - `Contact.Email = User.Email`
   - Most reliable match, used first

2. **FederationIdentifier Match** (Second Priority)
   - Transformation: `Contact.Email.replace('@', '_') + '@spokanemountaineers.org'`
   - Example: `jason@example.com` → `jason_example.com@spokanemountaineers.org`
   - Matches against `User.FederationIdentifier`

3. **Username Match** (Third Priority)
   - Pattern: `Contact.Email + '.smi'`
   - Example: `jason@example.com` → `jason@example.com.smi`
   - Matches against `User.Username`

This prioritized approach ensures:
- Most reliable matches are found first
- Handles various User naming conventions
- Avoids duplicate matches when multiple Users share the same email

## Security & Privacy Considerations

- ✅ Respects User privacy settings by redirecting to User profile pages
- ✅ Shows plain text (no link) when no related User exists
- ✅ Community users only see User profiles that respect Experience Cloud visibility rules
- ✅ Internal users retain standard Contact access for business operations
- ✅ No sensitive Contact data exposed to community users

## Troubleshooting Common Issues

### Bulk Sync Performance Issues?

**High SOQL Query Usage:**
- Ensure you're using `bulkSyncContactsToUsers()` instead of individual `syncContactToUser()` calls
- Check that you're processing contacts in batches of 50 or fewer
- Monitor query usage: `System.debug('Queries used: ' + Limits.getQueries());`

**Memory Limit Errors:**
- Reduce batch size from 50 to 25 if processing contacts with large data
- Use QueryLocator for very large datasets (>10,000 contacts)
- Clear collections between batches: `currentBatch.clear();`

**Slow Performance:**
- The bulk sync method should complete 1,000 contacts in <30 seconds
- If slower, check for custom triggers on Contact objects
- Verify User lookup indexes are in place

### Redirects Not Working?

- Verify `Contact.User_Lookup__c` field is populated
- Check that User records are active and have Community licenses
- Ensure Experience Cloud profile URL format matches `/s/profile/{UserId}`
- Verify the `eventParticipantRelatedList` component is properly added to the page layout

### Batch Sync Not Finding Matches?

- Verify User email addresses match Contact emails exactly (for Email match)
- Check for FederationIdentifier matches if email sync fails
- Review the transformation logic: `email.replace('@', '_') + '@spokanemountaineers.org'`
- Check for Username pattern matches: `email + '.smi'`
- Review batch job completion email for statistics

### Flow Trigger Not Firing?

- Verify `User_to_Contact_Sync_Trigger` Flow is active
- Check that User records have email addresses
- Ensure Contact records exist with matching emails
- Review Flow debug logs for any errors

### Component Not Displaying?

- Verify `eventParticipantRelatedList` component is added to the page layout
- Check that the component has access to the Event_Registration__c record
- Review browser console for JavaScript errors
- Ensure the Event_Registration__c has Event_Participant__c records

## Monitoring & Maintenance

- Monitor batch job completion emails for sync statistics
- Check Flow debug logs for any sync errors
- Review Experience Cloud access logs for redirect patterns
- Periodically verify Contact-User relationships are staying in sync
- Monitor SOQL query usage during bulk sync operations

## Future Enhancement Ideas

1. **Real-time sync**: Consider Platform Events for immediate Contact-User sync across systems
2. **Multiple User matching**: Add logic for handling multiple matching Users intelligently
3. **Custom matching rules**: Extend sync logic to include additional matching criteria beyond email
4. **Audit trail**: Add custom object to track Contact-User sync history and changes
5. **Admin dashboard**: Create a Lightning component for monitoring sync status and statistics

---

## Backout Plan: Rolling Back the Solution

This section provides a comprehensive rollback plan in case the Event Participant Redirect solution needs to be reverted.

### When to Consider Rollback

- **Performance Issues**: Significant slowdown in Event page loads or related list performance
- **Sync Problems**: Large-scale data corruption or incorrect Contact-User relationships
- **User Experience**: Negative feedback from community users or navigation issues
- **Security Concerns**: Unexpected privacy breaches or access control problems
- **Business Requirements**: Change in privacy policies or Event management approach

### Step-by-Step Rollback Process

#### Phase 1: Disable New Functionality

**1. Deactivate Flows**
- Navigate to Setup → Flows
- Find `User_to_Contact_Sync_Trigger` and `Sync_User_to_Contact`
- Click "Deactivate" for each Flow

**2. Remove Lightning Component**
- Edit Event Registration page layouts in Experience Cloud Builder
- Remove the `eventParticipantRelatedList` component
- Replace with standard related list if needed
- Save and publish the layout

#### Phase 2: Revert Data Model Changes (Optional)

**3. Clear Contact User Lookups (Optional)**
```java
// Execute in Anonymous Apex to clear all User lookups
List<Contact> contactsToUpdate = [
    SELECT Id, User_Lookup__c 
    FROM Contact 
    WHERE User_Lookup__c != null
    LIMIT 50000
];

for (Contact contact : contactsToUpdate) {
    contact.User_Lookup__c = null;
}

update contactsToUpdate;
System.debug('Cleared User lookup from ' + contactsToUpdate.size() + ' Contacts');
```

#### Phase 3: Remove Custom Components (Optional - Destructive)

**4. Delete Custom Fields**
```bash
# WARNING: This is destructive!
sf project delete source \
    --source-dir force-app/main/default/objects/Contact/fields/User_Lookup__c.field-meta.xml \
    --target-org your-org-alias
```

**5. Delete Apex Classes**
```bash
sf project delete source \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelper.cls \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelperTest.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatch.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatchTest.cls \
    --target-org your-org-alias
```

**6. Delete Flows**
```bash
sf project delete source \
    --source-dir force-app/main/default/flows/Sync_User_to_Contact.flow-meta.xml \
    --source-dir force-app/main/default/flows/User_to_Contact_Sync_Trigger.flow-meta.xml \
    --target-org your-org-alias
```

**7. Delete Lightning Component**
```bash
sf project delete source \
    --source-dir force-app/main/default/lwc/eventParticipantRelatedList \
    --target-org your-org-alias
```

### Rollback Validation

**Functionality Testing**
- [ ] Event pages load normally
- [ ] Event Participants related list shows standard Contact names
- [ ] Clicking participant names opens Contact records (original behavior)
- [ ] No broken links or error messages
- [ ] Performance returns to baseline levels

**Data Integrity Checks**
- [ ] Contact records are unchanged
- [ ] Event relationships remain intact
- [ ] No orphaned lookup relationships
- [ ] User data is preserved

---

**Remember**: Test rollback procedures in a sandbox environment before executing in production. Always have a recent backup available before making destructive changes.
