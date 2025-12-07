// =============================================================================
// Event Bot Service Account Setup Script
// =============================================================================
// This script creates a minimal-permission service account for posting
// event notifications to Chatter groups.
//
// Prerequisites:
// 1. Deploy the Event_Bot_Service permission set first:
//    sf project deploy start --target-org <your-org> --source-dir force-app/main/default/permissionsets
//
// 2. Then run this script to create the user and configure everything
// =============================================================================

System.debug('=== EVENT BOT SERVICE ACCOUNT SETUP ===');
System.debug('');

// Configuration - adjust these as needed
String botUsername = 'eventbot@spokanemountaineers.org.staging';
String botEmail = 'webdev@spokanemountaineers.org'; // Notifications go here
String botFirstName = 'Event';
String botLastName = 'Bot';
String botAlias = 'evtbot';
String permissionSetName = 'Event_Bot_Service';

// Step 1: Check if user already exists
List<User> existingUsers = [
    SELECT Id, Username, IsActive, Profile.Name
    FROM User
    WHERE Username = :botUsername
    LIMIT 1
];

User eventBot;

if (!existingUsers.isEmpty()) {
    eventBot = existingUsers[0];
    System.debug('✓ Event Bot user already exists: ' + eventBot.Id);
    System.debug('  Profile: ' + eventBot.Profile.Name);
    System.debug('  Active: ' + eventBot.IsActive);
    
    // Ensure user is active
    if (!eventBot.IsActive) {
        eventBot.IsActive = true;
        update eventBot;
        System.debug('  → Activated user');
    }
} else {
    System.debug('Creating new Event Bot user...');
    
    // Get a suitable profile - prefer "Standard Platform User" or "Standard User"
    List<Profile> profiles = [
        SELECT Id, Name, UserLicense.Name
        FROM Profile
        WHERE Name IN ('Standard Platform User', 'Standard User', 'Minimum Access - Salesforce')
        AND UserLicense.Name IN ('Salesforce Platform', 'Salesforce')
        ORDER BY Name
        LIMIT 1
    ];
    
    if (profiles.isEmpty()) {
        // Fallback to any Salesforce license profile
        profiles = [
            SELECT Id, Name
            FROM Profile
            WHERE UserLicense.Name = 'Salesforce'
            LIMIT 1
        ];
    }
    
    if (profiles.isEmpty()) {
        System.debug('ERROR: No suitable profile found. Need a Salesforce or Salesforce Platform license profile.');
        return;
    }
    
    Profile selectedProfile = profiles[0];
    System.debug('Using profile: ' + selectedProfile.Name);
    
    // Create the user
    eventBot = new User(
        Username = botUsername,
        Email = botEmail,
        FirstName = botFirstName,
        LastName = botLastName,
        Alias = botAlias,
        ProfileId = selectedProfile.Id,
        TimeZoneSidKey = 'America/Los_Angeles',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        IsActive = true
    );
    
    try {
        insert eventBot;
        System.debug('✓ Created Event Bot user: ' + eventBot.Id);
    } catch (Exception e) {
        System.debug('ERROR creating user: ' + e.getMessage());
        return;
    }
}

// Step 2: Assign Permission Set
System.debug('');
System.debug('Assigning permission set...');

List<PermissionSet> permSets = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE Name = :permissionSetName
    LIMIT 1
];

if (permSets.isEmpty()) {
    System.debug('WARNING: Permission set "' + permissionSetName + '" not found.');
    System.debug('Deploy it first: sf project deploy start --source-dir force-app/main/default/permissionsets');
} else {
    // Check if already assigned
    List<PermissionSetAssignment> existingAssignments = [
        SELECT Id
        FROM PermissionSetAssignment
        WHERE AssigneeId = :eventBot.Id
        AND PermissionSetId = :permSets[0].Id
    ];
    
    if (existingAssignments.isEmpty()) {
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = eventBot.Id,
            PermissionSetId = permSets[0].Id
        );
        insert psa;
        System.debug('✓ Assigned permission set: ' + permissionSetName);
    } else {
        System.debug('✓ Permission set already assigned');
    }
}

// Step 3: Add to all Chatter groups
System.debug('');
System.debug('Adding to Chatter groups...');

List<CollaborationGroup> allGroups = [
    SELECT Id, Name, CollaborationType
    FROM CollaborationGroup
    WHERE CollaborationType = 'Public'
];

Set<Id> existingGroupIds = new Set<Id>();
for (CollaborationGroupMember cgm : [
    SELECT CollaborationGroupId
    FROM CollaborationGroupMember
    WHERE MemberId = :eventBot.Id
]) {
    existingGroupIds.add(cgm.CollaborationGroupId);
}

List<CollaborationGroupMember> membersToAdd = new List<CollaborationGroupMember>();
for (CollaborationGroup grp : allGroups) {
    if (!existingGroupIds.contains(grp.Id)) {
        membersToAdd.add(new CollaborationGroupMember(
            MemberId = eventBot.Id,
            CollaborationGroupId = grp.Id,
            CollaborationRole = 'Standard'
        ));
    }
}

if (!membersToAdd.isEmpty()) {
    try {
        insert membersToAdd;
        System.debug('✓ Added to ' + membersToAdd.size() + ' Chatter group(s)');
    } catch (Exception e) {
        System.debug('WARNING: Could not add to some groups: ' + e.getMessage());
    }
} else {
    System.debug('✓ Already a member of all ' + allGroups.size() + ' public groups');
}

// Step 4: Delete existing scheduled job (if any)
System.debug('');
System.debug('Checking scheduled jobs...');

List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name, OwnerId
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Event Chatter Batch Posting - Daily 5am'
];

if (!existingJobs.isEmpty()) {
    for (CronTrigger ct : existingJobs) {
        System.abortJob(ct.Id);
        System.debug('✓ Deleted existing scheduled job');
    }
}

// Step 5: Summary
System.debug('');
System.debug('=== SETUP COMPLETE ===');
System.debug('');
System.debug('Event Bot User:');
System.debug('  ID: ' + eventBot.Id);
System.debug('  Username: ' + botUsername);
System.debug('');
System.debug('NEXT STEPS:');
System.debug('1. Go to Setup → Users → find "' + botUsername + '"');
System.debug('2. Click "Login" to impersonate Event Bot');
System.debug('3. Open Developer Console and run:');
System.debug('');
System.debug('   String cronExpr = \'0 0 12 * * ?\'; // 5am Pacific');
System.debug('   EventChatterBatchPoster batch = new EventChatterBatchPoster();');
System.debug('   System.schedule(\'Event Chatter Batch Posting - Daily 5am\', cronExpr, batch);');
System.debug('');
System.debug('4. Log out to return to your admin account');
System.debug('');
