// Script to add sm-client@prolocity.com to all existing Chatter groups
// This ensures the user can post to all activity group Chatter groups

// Get the service account user
List<User> serviceAccountList = [
    SELECT Id, Name, Username
    FROM User 
    WHERE Username = 'sm-client@prolocity.com'
    LIMIT 1
];

if (serviceAccountList.isEmpty()) {
    System.debug('ERROR: sm-client@prolocity.com user not found!');
    System.debug('Please verify the user exists and is active.');
} else {
    User serviceAccount = serviceAccountList[0];
    System.debug('Service Account: ' + serviceAccount.Name + ' (' + serviceAccount.Id + ')');
    System.debug('Username: ' + serviceAccount.Username);

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
        System.debug('WARNING: sm-client@prolocity.com is not a member of any Experience Cloud sites.');
        System.debug('Site-specific Chatter groups will be skipped.');
        System.debug('To add to site-specific groups, first add the user as a member of the Experience Cloud site(s).');
        System.debug('');
    } else {
        System.debug('sm-client@prolocity.com is a member of ' + siteNetworkIds.size() + ' Experience Cloud site(s)');
        for (Id networkId : siteNetworkIds) {
            System.debug('  Network ID: ' + networkId);
        }
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

    System.debug('User is already a member of ' + existingGroupIds.size() + ' groups');

    // Create memberships for groups the user is not already in
    List<CollaborationGroupMember> membersToAdd = new List<CollaborationGroupMember>();
    Integer addedCount = 0;
    Integer skippedCount = 0;
    Integer siteGroupSkippedCount = 0;

    for (CollaborationGroup collaborationGroup : allGroups) {
        if (!existingGroupIds.contains(collaborationGroup.Id)) {
            // Check if this is a site-specific group and if user is a site member
            if (collaborationGroup.NetworkId != null && !siteNetworkIds.contains(collaborationGroup.NetworkId)) {
                System.debug('⚠ Skipping site-specific group: ' + collaborationGroup.Name + ' (user not a site member)');
                skippedCount++;
                siteGroupSkippedCount++;
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
        }
    }

    if (membersToAdd.isEmpty()) {
        System.debug('');
        System.debug('✓ User is already a member of all accessible groups (' + allGroups.size() + ' total)');
        if (siteGroupSkippedCount > 0) {
            System.debug('  Note: ' + siteGroupSkippedCount + ' site-specific group(s) were skipped (user not a site member)');
        }
    } else {
        System.debug('');
        System.debug('Attempting to add user to ' + addedCount + ' group(s)...');
        System.debug('');
        
        try {
            insert membersToAdd;
            System.debug('✓ SUCCESS: Added user to ' + addedCount + ' group(s)');
            System.debug('  Skipped ' + skippedCount + ' group(s) (already a member)');
            if (siteGroupSkippedCount > 0) {
                System.debug('  Skipped ' + siteGroupSkippedCount + ' site-specific group(s) (user not a site member)');
            }
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
            System.debug('');
            System.debug('Attempting to add individually to identify which groups failed...');
            System.debug('');
            
            // Try to insert individually to see which ones fail
            Integer successCount = 0;
            Integer failCount = 0;
            for (CollaborationGroupMember member : membersToAdd) {
                try {
                    insert member;
                    successCount++;
                    // Find the group name for logging
                    for (CollaborationGroup collaborationGroup : allGroups) {
                        if (collaborationGroup.Id == member.CollaborationGroupId) {
                            System.debug('✓ Successfully added to: ' + collaborationGroup.Name);
                            break;
                        }
                    }
                } catch (DmlException individualError) {
                    failCount++;
                    // Find the group name for logging
                    for (CollaborationGroup collaborationGroup : allGroups) {
                        if (collaborationGroup.Id == member.CollaborationGroupId) {
                            String errorMsg = individualError.getMessage();
                            if (errorMsg.contains('INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY') || 
                                errorMsg.contains('Only site members can be added')) {
                                System.debug('⚠ Skipped site-specific group: ' + collaborationGroup.Name + ' (requires Experience Cloud site membership)');
                            } else {
                                System.debug('✗ Failed to add to: ' + collaborationGroup.Name + ' - ' + errorMsg);
                            }
                            break;
                        }
                    }
                }
            }
            
            System.debug('');
            System.debug('Summary:');
            System.debug('  Successfully added: ' + successCount);
            System.debug('  Failed: ' + failCount);
            if (siteGroupSkippedCount > 0) {
                System.debug('  Skipped (site-specific): ' + siteGroupSkippedCount);
            }
        }
    }
}

