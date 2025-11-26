// Script to create at least 3 events in each activity group for testing batch event processing
// This creates approved events that will be picked up by the EventChatterBatchPoster batch job

System.debug('=== CREATING TEST EVENTS BY ACTIVITY GROUP ===');
System.debug('');

// Step 1: Get distinct Activity_Group__c values from existing records
// If no existing records, use common activity groups
Set<String> activityGroups = new Set<String>();

List<Event_Registration__c> existingEvents = [
    SELECT Activity_Group__c
    FROM Event_Registration__c
    WHERE Activity_Group__c != null
    AND Activity_Group__c != ''
    WITH SECURITY_ENFORCED
    LIMIT 1000
];

for (Event_Registration__c evt : existingEvents) {
    if (String.isNotBlank(evt.Activity_Group__c)) {
        activityGroups.add(evt.Activity_Group__c);
    }
}

// If no existing activity groups found, use common defaults
if (activityGroups.isEmpty()) {
    System.debug('No existing activity groups found. Using default activity groups.');
    activityGroups.add('Hiking');
    activityGroups.add('Climbing');
    activityGroups.add('Backpacking');
    activityGroups.add('Skiing');
    activityGroups.add('Mountaineering');
    activityGroups.add('Cycling');
} else {
    System.debug('Found ' + activityGroups.size() + ' existing activity groups.');
}

System.debug('Activity groups to create events for: ' + String.join(new List<String>(activityGroups), ', '));
System.debug('');

// Step 2: Get a User to use as Leader
// First try current user, if that fails, get any active user
Id leaderUserId = UserInfo.getUserId();
User leaderUser = [SELECT Id, Name, IsActive FROM User WHERE Id = :leaderUserId LIMIT 1];

if (!leaderUser.IsActive) {
    System.debug('Current user is not active. Finding an active user...');
    List<User> activeUsers = [
        SELECT Id, Name
        FROM User
        WHERE IsActive = true
        WITH SECURITY_ENFORCED
        LIMIT 1
    ];
    
    if (!activeUsers.isEmpty()) {
        leaderUserId = activeUsers[0].Id;
        System.debug('Using active user: ' + activeUsers[0].Name);
    } else {
        System.debug('ERROR: No active users found. Cannot create events.');
        return;
    }
} else {
    System.debug('Using current user as leader: ' + leaderUser.Name);
}
System.debug('');

// Step 3: Create at least 3 events for each activity group
Integer eventsCreated = 0;
Integer eventsFailed = 0;
List<Event_Registration__c> eventsToInsert = new List<Event_Registration__c>();
DateTime baseDate = System.now().addDays(7); // Start events 7 days from now

for (String activityGroup : activityGroups) {
    System.debug('Creating events for activity group: ' + activityGroup);
    
    // Create 3-5 events per activity group for variety
    Integer eventCount = 3 + Math.mod(Integer.valueOf(Math.random() * 100), 3); // 3-5 events
    
    for (Integer i = 1; i <= eventCount; i++) {
        Event_Registration__c event = new Event_Registration__c(
            Name = activityGroup + ' Event ' + i + ' - ' + DateTime.now().format('MM/dd'),
            Activity_Group__c = activityGroup,
            Status__c = 'Approved', // Approved so batch job will pick them up
            Start__c = baseDate.addDays(i * 2 + Integer.valueOf(Math.random() * 7)), // Spread out over 2-3 weeks
            Location__c = 'Test Location ' + i + ' - ' + activityGroup,
            Leader__c = leaderUserId,
            Chatter_Posted__c = false // Not yet posted, so batch job will process them
        );
        
        eventsToInsert.add(event);
    }
    
    System.debug('  Added ' + eventCount + ' events for ' + activityGroup);
}

System.debug('');
System.debug('Total events to create: ' + eventsToInsert.size());
System.debug('');

// Step 4: Insert events (use Database.insert to handle partial failures)
List<Database.SaveResult> results = Database.insert(eventsToInsert, false);

// Count successes and failures
for (Integer i = 0; i < results.size(); i++) {
    Database.SaveResult result = results[i];
    Event_Registration__c event = eventsToInsert[i];
    
    if (result.isSuccess()) {
        eventsCreated++;
    } else {
        eventsFailed++;
        String errorMsg = result.getErrors().isEmpty() ? 'Unknown error' : result.getErrors()[0].getMessage();
        System.debug('Failed to create event: ' + event.Name + ' - Error: ' + errorMsg);
        
        // Some errors are expected (e.g., Flow validation failures) but we continue
        if (!errorMsg.contains('Notify Subscribers') && !errorMsg.contains('Event Process')) {
            System.debug('  Unexpected error for: ' + event.Activity_Group__c);
        }
    }
}

System.debug('');
System.debug('=== RESULTS ===');
System.debug('Events created successfully: ' + eventsCreated);
System.debug('Events failed: ' + eventsFailed);
System.debug('Total activity groups: ' + activityGroups.size());
System.debug('');

// Step 5: Verify creation by activity group
Map<String, Integer> eventsByGroup = new Map<String, Integer>();

List<Event_Registration__c> createdEvents = [
    SELECT Id, Name, Activity_Group__c, Status__c, Start__c, Chatter_Posted__c
    FROM Event_Registration__c
    WHERE Id IN :eventsToInsert
    AND Id != null
];

for (Event_Registration__c evt : createdEvents) {
    String groupName = String.isNotBlank(evt.Activity_Group__c) ? evt.Activity_Group__c : 'Unknown';
    Integer count = eventsByGroup.containsKey(groupName) ? eventsByGroup.get(groupName) : 0;
    eventsByGroup.put(groupName, count + 1);
}

System.debug('Events created by activity group:');
for (String groupName : eventsByGroup.keySet()) {
    System.debug('  ' + groupName + ': ' + eventsByGroup.get(groupName) + ' events');
}

System.debug('');
System.debug('=== SCRIPT COMPLETED ===');
System.debug('These events are ready to be processed by the EventChatterBatchPoster batch job.');
System.debug('Run: Database.executeBatch(new EventChatterBatchPoster(), 200);');

