# Protecting Member Privacy in Event Participant Lists

*Published: November 5, 2025 | Category: Community Solutions*

## The Problem We Solved

When members of the Spokane Mountaineers browse upcoming events in our community website, they can see who else is planning to attend. This is great for networking and coordination - but we discovered a privacy issue.

When someone clicked on a participant's name, they were taken directly to that person's full Contact record in Salesforce. This exposed information that should remain private: phone numbers, addresses, and other personal details that aren't meant for public viewing.

### Why This Happened

Salesforce's Event system is designed for business use, where seeing full Contact details might be appropriate. But in a community website where members interact with each other, we needed a different approach - one that respects privacy while still allowing members to connect.

## Our Solution: Smart Profile Links

Instead of showing full Contact records, we built a system that intelligently routes members to appropriate profile pages:

- **If a member has a community profile** → Clicking their name takes you to their public User profile (which respects privacy settings)
- **If no community profile exists** → The name appears as plain text (not clickable)

This way, members can still see who's attending events, but they only access information that's meant to be public.

## How It Works

### The Bridge Between Contacts and Users

At the heart of our solution is a simple connection: we link each Contact record to its corresponding User account (if one exists). This "bridge" allows us to know when someone has a community profile and should be clickable.

### Automatic Synchronization

We didn't want to manually maintain thousands of these connections. So we built automatic processes that:

1. **Keep new connections in sync** - When a new User account is created, it automatically links to the matching Contact
2. **Backfill existing data** - We ran a one-time process that matched 1,732 out of 1,747 existing Contacts to their User accounts (99.14% success rate)
3. **Handle updates** - If a User's email changes, the connection updates automatically

### Smart Matching

The system matches Contacts to Users using a prioritized approach:

1. **Email match** (most reliable) - If the Contact email matches the User email exactly
2. **Federation ID match** - For users who log in through external systems (like Google Workspace)
3. **Username pattern match** - For users with specific username formats

This ensures we find the right match even when email addresses aren't exactly the same.

## What Members See

### Before Our Solution

- Clicking a participant name → Full Contact record with private information
- No privacy controls
- Potential for information exposure

### After Our Solution

- Clicking a participant name → Public User profile (if available)
- Privacy settings respected
- Plain text display when no profile exists
- Seamless experience - members don't notice the difference

## The Technical Approach

### What We Built

1. **Custom Field** - Added a lookup field on Contact records that points to the related User account
2. **Automation** - Created Flows that automatically maintain these connections
3. **Custom Component** - Built a replacement for the standard participant list that handles the smart routing
4. **Batch Processing** - Developed efficient processes to sync thousands of records at once

### Why This Approach Works

- **Non-disruptive** - Works with Salesforce's existing Event system
- **Scalable** - Handles our growing membership automatically
- **Maintainable** - Uses standard Salesforce tools and patterns
- **Flexible** - Can be extended or modified as needs change

## Results and Impact

### Privacy Protection

✅ Members' private information is no longer exposed through Event participant lists  
✅ Only public profile information is accessible  
✅ Privacy settings are respected automatically  

### User Experience

✅ Seamless navigation - members don't notice the change  
✅ Consistent appearance - looks like standard Salesforce lists  
✅ Works for both linked and unlinked participants  

### Data Quality

✅ 99.14% of Contacts successfully linked to Users  
✅ Automatic maintenance keeps connections current  
✅ Handles edge cases gracefully  

## For Administrators

### Monitoring Sync Status

You can check how many Contacts are linked to Users:

```java
// Run in Developer Console or Anonymous Apex
Integer totalContacts = [SELECT COUNT() FROM Contact WHERE Email != NULL];
Integer syncedContacts = [SELECT COUNT() FROM Contact WHERE Email != NULL AND User_Lookup__c != NULL];
Integer unsyncedContacts = totalContacts - syncedContacts;

System.debug('Total contacts with email: ' + totalContacts);
System.debug('Contacts synced to Users: ' + syncedContacts);
System.debug('Contacts needing sync: ' + unsyncedContacts);
System.debug('Sync completion rate: ' + (totalContacts > 0 ? ((syncedContacts * 100.0 / totalContacts)).setScale(2) + '%' : '0%'));
```

### Manual Sync (When Needed)

If you need to sync specific Contacts manually:

1. Navigate to the Contact record
2. Look for the "Sync to User" button or Flow action
3. Click to trigger the sync process

### Troubleshooting

**Participant names aren't clickable:**
- The Contact may not have a linked User account
- This is normal - not all Contacts have corresponding User accounts
- The name will display as plain text

**Links go to wrong profiles:**
- Check that the Contact's email matches the User's email
- Verify the User account is active and has a Community license
- Review the sync status for that Contact

**Sync isn't working:**
- Verify the automation Flows are active
- Check that Contacts have email addresses
- Ensure User records exist with matching information

## Future Enhancements

We're considering several improvements:

1. **Better matching** - Enhanced algorithms to find more matches
2. **Audit trail** - Track when and how Contacts are linked to Users
3. **Admin dashboard** - Visual interface for monitoring sync status
4. **Real-time updates** - Even faster synchronization across systems

## Key Takeaways

This solution demonstrates how thoughtful design can solve privacy challenges while maintaining a great user experience. By working with Salesforce's existing systems rather than against them, we created a solution that:

- Protects member privacy
- Maintains system integrity
- Scales with our organization
- Requires minimal ongoing maintenance

The approach balances technical sophistication with practical simplicity, providing robust privacy protection that our members can trust.

---

**For Technical Details**: See the companion article "Solving Event Participant Privacy in Experience Cloud" for complete implementation details, code examples, and deployment instructions.

