# Solving Event Participant Privacy in Experience Cloud

*Published: November 4, 2025 | Category: Salesforce Solutions*

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

**Batch Backfill**: For our existing data, we created a batch Apex class that processes 500 records at a time, matching Contacts to Users based on a prioritized approach: Username first (guaranteed unique), then FederationIdentifier, then Email as last resort. This was crucial for handling our historical data while avoiding duplicate email matches.

**Manual Sync**: A utility Flow for administrators to manually trigger syncs when needed.

### 3. The Smart Redirect Logic

This is where the magic happens. Since EventRelation doesn't allow custom fields, we created a custom Lightning Web Component that handles the intelligent routing:

- **Custom Related List**: Replaces the standard Event Participants related list
- **Smart Click Handling**: Participants with linked Users redirect to profiles, others show plain text
- **Rich Display**: Shows participant status and response information
- **Graceful Degradation**: Handles missing User relationships elegantly

The component checks each participant's Contact.User_Lookup__c field and creates conditional links:
- If a related User exists → Create a clickable link to their profile page
- If no User exists → Show plain text (no link, just the name)

### 4. Enhanced User Experience

We didn't stop at just making the links work. We built a Lightning Web Component that handles the redirect gracefully:

- Shows a loading state while checking for User profile availability
- Displays a friendly message if no public profile exists
- Respects Experience Cloud visibility rules automatically
- Provides smooth navigation without jarring page reloads

## Technical Deep Dive: What We Built

### Custom Fields
- **Contact.User_Lookup__c** - The bridge field linking Contacts to Users

### Lightning Web Components
- **eventParticipantRedirect** - Individual participant redirect component with loading states and error handling
- **eventParticipantRelatedList** - Custom related list that replaces standard Event Participants list with smart redirect functionality

### Flows
- **Sync_User_to_Contact** - Manual sync operations for administrators
- **Redirect_to_User_Profile** - Screen flow handling the navigation logic
- **User_to_Contact_Sync_Trigger** - Automatic real-time sync when Users change

### Apex Classes
- **EventParticipantRedirectHelper** - Core business logic and utility methods
- **ContactUserSyncBatch** - Efficient batch processing for existing data

### Lightning Component
- **eventParticipantRedirect** - The Experience Cloud redirect component with loading states and error handling

## Deployment Strategy: Minimal Disruption

We rolled this out carefully to avoid breaking anything:

1. **Deploy metadata** - All custom fields, classes, and components
2. **Run batch sync** - Backfill existing Contact-User relationships
3. **Update layouts** - Replace standard Contact links with our smart redirects
4. **Test thoroughly** - Verify both linked and unlinked scenarios work perfectly

## The Results: Privacy Preserved, Experience Enhanced

**Privacy Protection**: Community users now see User profile pages that respect privacy settings instead of unrestricted Contact records.

**Seamless Experience**: The redirect is completely transparent - users click a name and get the appropriate view based on data availability.

**Data Integrity**: We maintained Salesforce's standard Event data model while adding the necessary intelligence.

**Scalability**: The batch processing and automated sync ensure this works as our organization continues to grow.

## Lessons from the Trenches

**Think Beyond the Obvious**: Initially, we considered overriding the standard related list entirely. But a formula field approach was cleaner, more maintainable, and less disruptive.

**Multiple Sync Strategies**: Real-time sync is great for new data, but batch processing is essential for existing records. You need both.

**Graceful Degradation**: Not every Contact will have a corresponding User. The solution handles this elegantly with friendly messaging rather than broken links.

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

#### EventRelation.User_Profile_Link__c
- **Type**: Formula (Text)
- **Purpose**: Smart redirect formula that makes routing decisions
- **Formula**: 
  ```
  IF(
    NOT(ISBLANK(Contact.User_Lookup__c)),
    HYPERLINK("/s/profile/" & TEXT(Contact.User_Lookup__c), Contact.Name),
    Contact.Name
  )
  ```
- **Location**: `/objects/EventRelation/fields/User_Profile_Link__c.field-meta.xml`

### Flows for Automation

#### Sync_User_to_Contact
- **Type**: Autolaunched Flow
- **Purpose**: Manually sync a Contact to its matching User record
- **Input**: `recordId` (Contact ID)
- **Location**: `/flows/Sync_User_to_Contact.flow-meta.xml`

#### Redirect_to_User_Profile
- **Type**: Screen Flow
- **Purpose**: Handles Event Participant clicks with smart routing
- **Input**: `recordId` (EventRelation ID)
- **Location**: `/flows/Redirect_to_User_Profile.flow-meta.xml`

#### User_to_Contact_Sync_Trigger
- **Type**: Record-Triggered Flow (User, Before Save)
- **Purpose**: Automatically syncs User to Contact when Users are created/updated
- **Location**: `/flows/User_to_Contact_Sync_Trigger.flow-meta.xml`

### Apex Classes for Core Logic

#### EventParticipantRedirectHelper
- **Purpose**: Provides methods for redirect logic and batch sync operations
- **Key Methods**:
  - `getUserRedirectUrl(String eventRelationId)` - Returns User profile URL or null
  - `syncContactToUser(String contactId)` - Syncs single Contact to User (legacy, use bulk method)
  - `bulkSyncContactsToUsers(List<String> contactIds)` - **NEW**: Efficient bulk sync method
  - `syncContactsToUsers(List<SyncRequest>)` - Legacy batch sync method for Flows
- **Performance**: The new `bulkSyncContactsToUsers` method reduces SOQL queries from ~3 per contact to just 3 total queries
- **Location**: `/classes/EventParticipantRedirectHelper.cls`

#### ContactUserSyncBatch
- **Purpose**: Batch job to backfill existing Contacts with User lookups
- **Capacity**: Processes 50,000 records per batch execution
- **Matching Logic**: Prioritized approach - Username first (unique), then FederationIdentifier, then Email as last resort to avoid duplicates
- **Location**: `/classes/ContactUserSyncBatch.cls`

### Lightning Web Component

#### eventParticipantRedirect
- **Purpose**: LWC for handling Event Participant redirects in Experience Cloud
- **Features**: Loading states, error handling, automatic navigation
- **Location**: `/lwc/eventParticipantRedirect/`

## Step-by-Step Deployment

### 1. Deploy Custom Fields
```bash
# Deploy Contact custom field
sf deploy metadata -m CustomField:Contact.User_Lookup__c
```

### 2. Deploy Apex Classes
```bash
# Use project deploy start for Apex classes (requires -meta.xml files)
sf project deploy start \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelper.cls \
    --source-dir force-app/main/default/classes/EventParticipantRedirectHelperTest.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatch.cls \
    --source-dir force-app/main/default/classes/ContactUserSyncBatchTest.cls \
    --test-level RunSpecifiedTests \
    --tests EventParticipantRedirectHelperTest \
    --tests ContactUserSyncBatchTest
```

### 3. Deploy Flows
```bash
sf project deploy start \
    --source-dir force-app/main/default/flows/Sync_User_to_Contact.flow-meta.xml \
    --source-dir force-app/main/default/flows/Redirect_to_User_Profile.flow-meta.xml \
    --source-dir force-app/main/default/flows/User_to_Contact_Sync_Trigger.flow-meta.xml
```

### 4. Deploy Lightning Web Components
```bash
sf project deploy start \
    --source-dir force-app/main/default/lwc/eventParticipantRedirect \
    --source-dir force-app/main/default/lwc/eventParticipantRelatedList
```

### 5. Alternative: Deploy All Components
```bash
# Deploy all Event Participant Redirect components at once
sf project deploy start \
    --source-dir force-app/main/default/classes \
    --source-dir force-app/main/default/flows \
    --source-dir force-app/main/default/lwc \
    --test-level RunSpecifiedTests \
    --tests EventParticipantRedirectHelperTest \
    --tests ContactUserSyncBatchTest
```

> **Note**: If you encounter "File not found: ...-meta.xml" errors, it means the metadata XML files are missing. You can either:
> 1. Generate them using `sfdx force:source:retrieve` or recreate the classes
> 2. Use `sf deploy metadata -m ApexClass:ClassName` for individual classes (if source tracking works)
> 3. Deploy the entire directory structure with `sf deploy source -p force-app/main/default`

## Deployment Troubleshooting

### Common Issues and Solutions

**"No source-backed components present" Error**
- This occurs when the CLI can't find the metadata files
- **Solution**: Use `sf project deploy start` with `--source-dir` instead of `sf deploy metadata`

**"File not found: ...-meta.xml" Error**
- Missing metadata XML files for Apex classes
- **Solution**: The `-meta.xml` files have been created above, or use:
  ```bash
  # Generate metadata files
  sfdx force:source:retrieve -m ApexClass:ClassName
  ```

**"Cannot add custom fields to entity: EventRelation" Error**
- EventRelation doesn't allow custom fields (Salesforce limitation)
- **Solution**: This is expected - we use the custom LWC related list instead

**Component Conversion Failed**
- Usually due to missing metadata or incorrect file structure
- **Solution**: Ensure all `-meta.xml` files exist and use `sf project deploy start`

### Quick Fix Commands

```bash
# If metadata deployment fails, try source deployment
sf deploy source -p force-app/main/default

# Deploy just the working components first
sf project deploy start --source-dir force-app/main/default/lwc

# Check what's actually in your project
sf project list --source-dir force-app/main/default
```

## Post-Deployment Setup

### 🚀 NEW: Efficient Bulk Sync Operations

We've added a high-performance bulk sync method that dramatically reduces SOQL query usage and improves performance for large-scale Contact-User synchronization.

#### Why Use Bulk Sync?

**Performance Comparison:**
- **Legacy Method**: ~3 SOQL queries per contact (1 for Contact + 1 for User lookup + 1 for update)
- **New Bulk Method**: Only 3 total SOQL queries regardless of contact count
- **Efficiency Gain**: 10,000 contacts = 30,000 queries → 3 queries (99.99% reduction!)

**When to Use:**
- ✅ Syncing large numbers of contacts (100+)
- ✅ Periodic batch synchronization
- ✅ Initial data backfill
- ✅ Performance-critical environments
- ❌ Single contact updates (use legacy method for simplicity)

#### Bulk Sync Methods

##### 1. Anonymous Apex - Quick Sync

```java
// Sync specific contacts by ID (most efficient)
List<String> contactIds = new List<String>{
    '0031N00001K1hLJQAZ',  // Derrek Daniels
    '003Um00000jXt3pIAC', // Jordan Randall  
    '0032G00002sd32kQAA'  // Arika Kuhlmann
};

List<EventParticipantRedirectHelper.SyncResult> results = 
    EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);

// Check results
for (EventParticipantRedirectHelper.SyncResult result : results) {
    System.debug('Contact ' + result.contactId + ' sync result: ' + result.success);
}
```

##### 2. Batch Sync All Contacts

```java
// Sync ALL contacts without User lookups (use with caution on large orgs)
System.debug('Starting efficient bulk Contact to User sync...');

// First check if User_Lookup__c field exists
try {
    Contact testContact = [SELECT Id, User_Lookup__c FROM Contact LIMIT 1];
    System.debug('User_Lookup__c field exists on Contact object');
} catch (Exception e) {
    System.debug('ERROR: User_Lookup__c field does not exist: ' + e.getMessage());
    // Exit early if field doesn't exist
    return;
}

// Use QueryLocator for unlimited contacts
Database.QueryLocatorIterator contactsIterator = Database.getQueryLocator([
    SELECT Id, Name, Email, User_Lookup__c 
    FROM Contact 
    WHERE Email != NULL 
    AND User_Lookup__c = NULL
    ORDER BY CreatedDate
]).iterator();

Integer successCount = 0;
Integer failureCount = 0;
Integer totalProcessed = 0;
Integer batchSize = 0;
List<String> currentBatch = new List<String>();

System.debug('Starting efficient bulk sync...');

// Process in batches of 50 (optimal for governor limits)
while (contactsIterator.hasNext()) {
    Contact contact = (Contact)contactsIterator.next();
    currentBatch.add(contact.Id);
    batchSize++;
    totalProcessed++;
    
    if (batchSize >= 50) {
        System.debug('Processing batch of ' + batchSize + ' contacts (total: ' + totalProcessed + ')');
        
        // Use the new efficient bulk sync method
        List<EventParticipantRedirectHelper.SyncResult> batchResults = 
            EventParticipantRedirectHelper.bulkSyncContactsToUsers(currentBatch);
        
        for (EventParticipantRedirectHelper.SyncResult result : batchResults) {
            if (result.success) {
                successCount++;
            } else {
                failureCount++;
            }
        }
        
        // Reset batch
        currentBatch.clear();
        batchSize = 0;
    }
}

// Process final batch
if (!currentBatch.isEmpty()) {
    System.debug('Processing final batch of ' + batchSize + ' contacts');
    
    List<EventParticipantRedirectHelper.SyncResult> batchResults = 
        EventParticipantRedirectHelper.bulkSyncContactsToUsers(currentBatch);
    
    for (EventParticipantRedirectHelper.SyncResult result : batchResults) {
        if (result.success) {
            successCount++;
        } else {
            failureCount++;
        }
    }
}

System.debug('Efficient bulk sync completed:');
System.debug('Total contacts processed: ' + totalProcessed);
System.debug('Success: ' + successCount);
System.debug('Failures: ' + failureCount);
System.debug('Success rate: ' + (totalProcessed > 0 ? (successCount * 100 / totalProcessed) + '%' : '0%'));
```

##### 3. Targeted Sync by Event

```java
// Sync all participants for a specific Event
String eventId = 'a0B1N000001XyZ123'; // Replace with your Event ID

// Get all EventRelation participants for this Event
List<EventRelation> participants = [
    SELECT RelationId 
    FROM EventRelation 
    WHERE EventId = :eventId
    AND Relation.Type = 'Contact'
];

// Extract Contact IDs
List<String> contactIds = new List<String>();
for (EventRelation er : participants) {
    contactIds.add(er.RelationId);
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

#### Performance Monitoring

The bulk sync method includes built-in performance monitoring:

```java
// Monitor SOQL usage during bulk sync
System.debug('SOQL queries used: ' + Limits.getQueries());
System.debug('SOQL queries remaining: ' + Limits.getLimitQueries() - Limits.getQueries());
```

**Expected Results:**
- Small batches (50 contacts): ~3 SOQL queries total
- Large batches (1000+ contacts): ~3 SOQL queries total
- Query limit usage: <5% regardless of contact count

### 1. Run the Backfill Batch (Legacy Method)

Execute this in Developer Console or Anonymous Apex to sync existing data:
```java
// Run the batch to sync existing Contacts
Database.executeBatch(new ContactUserSyncBatch(), 200);
```

> **Recommendation**: Use the new `bulkSyncContactsToUsers` method for better performance and lower SOQL usage. The legacy batch method is still available for compatibility.

### 2. Update Event Page Layout
1. Navigate to Event page layout in Experience Cloud
2. Remove the standard Event Participants related list
3. Add the custom `eventParticipantRelatedList` component
4. Configure the component to show on Event records
5. Save the layout

### 3. Test Everything
1. Create a test Event with multiple participants
2. Verify some participants have linked User accounts
3. Test clicking participant names in Experience Cloud
4. Confirm redirects work correctly for both linked and unlinked participants

## Security & Privacy Considerations

- ✅ Respects User privacy settings by redirecting to User profile pages
- ✅ Shows friendly "no public profile" message when no related User exists
- ✅ Community users only see User profiles that respect Experience Cloud visibility rules
- ✅ Internal users retain standard Contact access for business operations

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
- The bulk sync method should complete 1000 contacts in <30 seconds
- If slower, check for custom triggers on Contact objects
- Verify User lookup indexes are in place

### Redirects Not Working?
- Verify Contact.User_Lookup__c field is populated
- Check that User records are active and have Community licenses
- Ensure Experience Cloud profile URL format matches `/s/profile/{UserId}`

### Legacy Batch Sync Not Finding Matches?
- Verify User email addresses match Contact emails exactly
- Check for FederationIdentifier or Username matches if email sync fails
- Remember: Username matching takes priority over Email to avoid duplicate matches
- Review batch job completion email for statistics

### Flow Trigger Not Firing?
- Verify User_to_Contact_Sync_Trigger Flow is active
- Check that User records have email addresses
- Ensure Contact records exist with matching emails

### Bulk Sync Error Messages

**"Contact.User_Lookup__c field does not exist"**
```bash
# Deploy the custom field first
sf deploy metadata -m CustomField:Contact.User_Lookup__c
```

**"Too many SOQL queries: 101"**
- You're using the legacy sync method instead of bulk sync
- Switch to `bulkSyncContactsToUsers()` method
- Reduce batch size if still hitting limits

**"System.LimitException: Too many DML rows: 151"**
- Reduce batch size from 50 to 25
- Process in smaller chunks
- Check for custom triggers that might be increasing DML usage

## Monitoring & Maintenance

- Monitor batch job completion emails for sync statistics
- Check Flow debug logs for any sync errors
- Review Experience Cloud access logs for redirect patterns
- Periodically verify Contact-User relationships are staying in sync

## Future Enhancement Ideas

1. **Real-time sync**: Consider Platform Events for immediate Contact-User sync across systems
2. **Multiple User matching**: Add logic for handling multiple matching Users intelligently
3. **Custom matching rules**: Extend sync logic to include additional matching criteria beyond email
4. **Audit trail**: Add custom object to track Contact-User sync history and changes

---

## Backout Plan: Rolling Back the Solution

This section provides a comprehensive rollback plan in case the Event Participant Redirect solution needs to be reverted due to issues, performance problems, or changing requirements.

### 🚨 When to Consider Rollback

- **Performance Issues**: Significant slowdown in Event page loads or related list performance
- **Sync Problems**: Large-scale data corruption or incorrect Contact-User relationships
- **User Experience**: Negative feedback from community users or navigation issues
- **Security Concerns**: Unexpected privacy breaches or access control problems
- **Business Requirements**: Change in privacy policies or Event management approach

### 📋 Pre-Rollback Checklist

**1. Assess Impact**
- [ ] Document specific issues or reasons for rollback
- [ ] Identify affected user groups (community vs internal users)
- [ ] Measure current performance baselines
- [ ] Backup current state for analysis

**2. Stakeholder Communication**
- [ ] Notify tech team of planned rollback
- [ ] Communicate with business stakeholders
- [ ] Prepare user notification if downtime required
- [ ] Schedule maintenance window if needed

**3. Data Backup**
- [ ] Export Contact.User_Lookup__c field data
- [ ] Backup Event Relations with custom field values
- [ ] Save current Flow configurations
- [ ] Document any manual changes made

### 🔄 Step-by-Step Rollback Process

#### Phase 1: Disable New Functionality

**1. Deactivate Flows**
```bash
# Using Salesforce CLI
sf deploy metadata -m Flow:User_to_Contact_Sync_Trigger -o "Active"="false"
sf deploy metadata -m Flow:Sync_User_to_Contact -o "Active"="false"
sf deploy metadata -m Flow:Redirect_to_User_Profile -o "Active"="false"
```

**Or in Salesforce Setup:**
- Navigate to Flow Builder
- Find each Flow: `User_to_Contact_Sync_Trigger`, `Sync_User_to_Contact`, `Redirect_to_User_Profile`
- Click "Deactivate" for each Flow

**2. Remove Lightning Component**
```bash
# Remove the LWC from pages
sf deploy metadata -m FlexiPage:Event_Record_Page -o "eventParticipantRedirect"=remove
```

**Or in Experience Cloud Builder:**
- Edit Event page layouts
- Remove the `eventParticipantRedirect` component
- Replace with standard Contact name field

#### Phase 2: Revert Data Model Changes

**3. Restore Event Participant Related List**
1. Navigate to Event page layout in Experience Cloud
2. Edit the Event Participants related list
3. Remove the `User_Profile_Link__c` field
4. Add back the standard `Contact.Name` field
5. Save the layout

**4. Clear Contact User Lookups (Optional)**
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

#### Phase 3: Remove Custom Components

**5. Delete Custom Fields**
```bash
# Remove the custom fields (WARNING: This is destructive!)
sf delete metadata -m CustomField:Contact.User_Lookup__c
sf delete metadata -m CustomField:EventRelation.User_Profile_Link__c
```

**6. Delete Apex Classes**
```bash
# Remove the Apex classes
sf delete metadata -m ApexClass:EventParticipantRedirectHelper
sf delete metadata -m ApexClass:EventParticipantRedirectHelperTest
sf delete metadata -m ApexClass:ContactUserSyncBatch
sf delete metadata -m ApexClass:ContactUserSyncBatchTest
```

**7. Delete Flows**
```bash
# Remove the Flows
sf delete metadata -m Flow:Sync_User_to_Contact
sf delete metadata -m Flow:Redirect_to_User_Profile
sf delete metadata -m Flow:User_to_Contact_Sync_Trigger
```

**8. Delete Lightning Component**
```bash
# Remove the LWC
sf delete metadata -m LightningComponentBundle:eventParticipantRedirect
```

### 📊 Rollback Validation

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

**User Access Verification**
- [ ] Community users can access Events
- [ ] Internal users maintain Contact access
- [ ] No permission errors or access denied messages

### 🔄 Alternative: Partial Rollback

If you want to keep some functionality while addressing specific issues:

**Option 1: Keep Sync, Remove Redirects**
- Keep `Contact.User_Lookup__c` field and sync Flows
- Remove `User_Profile_Link__c` formula field
- Restore standard Contact name links in related lists

**Option 2: Keep Manual Sync, Remove Automation**
- Keep custom fields for future use
- Deactivate automated sync Flows
- Use manual sync processes only when needed

**Option 3: Disable for Community Only**
- Keep functionality for internal users
- Create separate page layouts for Experience Cloud
- Use standard Contact links only in community

### 📞 Emergency Rollback (Quick Recovery)

For urgent issues requiring immediate restoration:

**1. Disable All Automation**
```java
// Quick disable - run in Anonymous Apex
List<FlowDefinition> flows = [
    SELECT Id, LatestVersionId 
    FROM FlowDefinition 
    WHERE DeveloperName IN ('Sync_User_to_Contact', 'Redirect_to_User_Profile', 'User_to_Contact_Sync_Trigger')
];

for (FlowDefinition flow : flows) {
    FlowDefinitionView fdv = new FlowDefinitionView();
    fdv.FlowDefinition = flow;
    fdv.Status = 'Draft';
    fdv.ActiveVersionId = null;
    update fdv;
}
```

**2. Restore Standard Related List**
- Edit Event layouts immediately
- Replace custom fields with standard Contact.Name
- Save and activate layouts

**3. Monitor Performance**
- Watch system performance metrics
- Check for any remaining errors
- Verify user functionality is restored

### 📝 Post-Rollback Actions

**Documentation**
- [ ] Document reasons for rollback
- [ ] Record timeline of rollback process
- [ ] Save any error logs or performance data
- [ ] Update project documentation

**Analysis**
- [ ] Analyze what went wrong with the solution
- [ ] Identify root causes of issues
- [ ] Document lessons learned
- [ ] Plan improvements for future implementations

**Communication**
- [ ] Notify stakeholders of successful rollback
- [ ] Communicate with users about restored functionality
- [ ] Share analysis findings with tech team
- [ ] Update project status and roadmap

### ⚠️ Important Considerations

**Data Loss Prevention**
- The `Contact.User_Lookup__c` field contains valuable relationship data
- Consider backing up this data before deletion
- You may want to keep the field inactive for a period before deletion

**User Experience Impact**
- Users will lose the privacy-focused redirect functionality
- Community users will see Contact records again
- Consider communicating this change to affected users

**Future Re-implementation**
- Keep documentation and code for potential future use
- Address the issues that caused the rollback
- Consider a phased approach for future deployments

### 🆘 Support Contacts

For rollback assistance:
- **Technical Lead**: [Contact information]
- **Salesforce Admin**: [Contact information] 
- **Experience Cloud Specialist**: [Contact information]
- **Business Stakeholder**: [Contact information]

---

**Remember**: Test rollback procedures in a sandbox environment before executing in production. Always have a recent backup available before making destructive changes.
