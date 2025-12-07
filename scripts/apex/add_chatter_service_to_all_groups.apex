// Script to add Event Bot service account to all existing Chatter groups
// Run this once after creating the service account

// Get the service account user
List<User> serviceAccountList = [
    SELECT Id, Name, Username
    FROM User 
    WHERE Username = 'eventbot@spokanemountaineers.org.smi'
    LIMIT 1
];

if (serviceAccountList.isEmpty()) {
    System.debug('ERROR: Event Bot service account not found!');
    System.debug('Please create the user with username: eventbot@spokanemountaineers.org.smi');
    System.debug('Then run this script again.');
} else {
    User serviceAccount = serviceAccountList[0];
    System.debug('Service Account: ' + serviceAccount.Name + ' (' + serviceAccount.Id + ')');

    // Check if user is a member of any Experience Cloud sites
    Set<Id> siteNetworkIds = new Set<Id>();
    List<NetworkMember> siteMemberships = [
        SELECT NetworkId
        FROM NetworkMember
        WHERE MemberId = :serviceAccount.Id
    ];
    
    for (NetworkMember member : siteMemberships) {
        siteNetworkIds.add(member.NetworkId);
    }
    
    if (siteNetworkIds.isEmpty()) {
        System.debug('WARNING: Event Bot is not a member of any Experience Cloud sites.');
        System.debug('Site-specific Chatter groups will be skipped.');
        System.debug('To add Event Bot to site-specific groups, first run: add_event_bot_to_experience_site.apex');
        System.debug('');
    } else {
        System.debug('Event Bot is a member of ' + siteNetworkIds.size() + ' Experience Cloud site(s)');
    }

    // Get all Chatter groups (Public and Private)
    // Note: Groups with NetworkId are associated with Experience Cloud sites
    List<CollaborationGroup> allGroups = [
        SELECT Id, Name, CollaborationType, NetworkId
        FROM CollaborationGroup
        ORDER BY Name
    ];

    System.debug('Found ' + allGroups.size() + ' Chatter groups');

    // Get existing memberships to avoid duplicates
    Set<Id> existingGroupIds = new Set<Id>();
    List<CollaborationGroupMember> existingMembers = [
        SELECT CollaborationGroupId
        FROM CollaborationGroupMember
        WHERE MemberId = :serviceAccount.Id
    ];

    for (CollaborationGroupMember member : existingMembers) {
        existingGroupIds.add(member.CollaborationGroupId);
    }

    System.debug('Service account is already a member of ' + existingGroupIds.size() + ' groups');

    // Create memberships for groups the user is not already in
    List<CollaborationGroupMember> membersToAdd = new List<CollaborationGroupMember>();
    Integer addedCount = 0;
    Integer skippedCount = 0;

    for (CollaborationGroup collaborationGroup : allGroups) {
        if (!existingGroupIds.contains(collaborationGroup.Id)) {
            // Check if this is a site-specific group and if user is a site member
            if (collaborationGroup.NetworkId != null && !siteNetworkIds.contains(collaborationGroup.NetworkId)) {
                System.debug('⚠ Skipping site-specific group: ' + collaborationGroup.Name + ' (user not a site member)');
                skippedCount++;
                continue;
            }
            
            CollaborationGroupMember member = new CollaborationGroupMember();
            member.MemberId = serviceAccount.Id;
            member.CollaborationGroupId = collaborationGroup.Id;
            member.CollaborationRole = 'Standard'; // Standard member role
            membersToAdd.add(member);
            addedCount++;
        } else {
            skippedCount++;
            System.debug('Skipping ' + collaborationGroup.Name + ' - already a member');
        }
    }

    if (membersToAdd.isEmpty()) {
        System.debug('Service account is already a member of all ' + allGroups.size() + ' groups');
    } else {
        try {
            insert membersToAdd;
            System.debug('');
            System.debug('✓ SUCCESS: Added service account to ' + addedCount + ' group(s)');
            System.debug('  Skipped ' + skippedCount + ' group(s) (already a member)');
            System.debug('');
            System.debug('Groups added:');
            // List the groups added
            for (CollaborationGroupMember member : membersToAdd) {
                for (CollaborationGroup collaborationGroup : allGroups) {
                    if (collaborationGroup.Id == member.CollaborationGroupId) {
                        System.debug('  ✓ ' + collaborationGroup.Name + ' (' + collaborationGroup.CollaborationType + ')');
                        break;
                    }
                }
            }
        } catch (DmlException e) {
            System.debug('ERROR: Failed to add some memberships: ' + e.getMessage());
            System.debug('Some groups may have restrictions or the user may not have permission');
            
            // Try to insert individually to see which ones fail
            Integer siteGroupCount = 0;
            for (CollaborationGroupMember member : membersToAdd) {
                try {
                    insert member;
                    // Find the group name for logging
                    for (CollaborationGroup collaborationGroup : allGroups) {
                        if (collaborationGroup.Id == member.CollaborationGroupId) {
                            System.debug('✓ Successfully added to: ' + collaborationGroup.Name);
                            break;
                        }
                    }
                } catch (DmlException individualError) {
                    // Find the group name for logging
                    for (CollaborationGroup collaborationGroup : allGroups) {
                        if (collaborationGroup.Id == member.CollaborationGroupId) {
                            String errorMsg = individualError.getMessage();
                            if (errorMsg.contains('INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY') || 
                                errorMsg.contains('Only site members can be added')) {
                                System.debug('⚠ Skipped site-specific group: ' + collaborationGroup.Name + ' (requires Experience Cloud site membership)');
                                siteGroupCount++;
                            } else {
                                System.debug('✗ Failed to add to: ' + collaborationGroup.Name + ' - ' + errorMsg);
                            }
                            break;
                        }
                    }
                }
            }
            
            if (siteGroupCount > 0) {
                System.debug('');
                System.debug('NOTE: ' + siteGroupCount + ' group(s) were skipped because they are associated with Experience Cloud sites.');
                System.debug('To add Event Bot to site-specific groups, you must first add the user as a member of the Experience Cloud site(s).');
            }
        }
    }
}

