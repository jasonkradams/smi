/**
 * Helper class for posting event notifications to Chatter groups
 * 
 * Provides an invocable method to post new event notifications to the
 * corresponding activity group Chatter group with rich text formatting.
 */
public without sharing class EventChatterPostHelper {
    
    /**
     * Input wrapper for the invocable method
     */
    public class PostToChatterInput {
        @InvocableVariable(required=true label='Event Registration ID' description='The Event_Registration__c record ID')
        public Id eventRegistrationId;
        
        @InvocableVariable(required=true label='Activity Group Name' description='The activity group name (e.g., "Climbing", "Hiking")')
        public String activityGroupName;
    }
    
    /**
     * Gets the network ID for Chatter posting.
     * In batch context, Network.getNetworkId() returns null, so we need to
     * query for the Spokane Mountaineers community network.
     * @return The network ID, or null if not found
     */
    private static Id getNetworkId() {
        Id networkId = Network.getNetworkId();
        
        // If we're in batch context (networkId is null), query for the community network
        if (networkId == null) {
            List<Network> networks = [
                SELECT Id 
                FROM Network 
                WHERE Name = 'Spokane Mountaineers' 
                AND Status = 'Live'
                LIMIT 1
            ];
            
            if (!networks.isEmpty()) {
                networkId = networks[0].Id;
            }
        }
        
        return networkId;
    }
    
    /**
     * Posts a notification about a new event to the corresponding Chatter group
     * @param inputs List of PostToChatterInput containing event details
     */
    @InvocableMethod(label='Post Event to Chatter Group' description='Posts a notification about a new event to the corresponding activity group Chatter group')
    public static void postEventToChatterGroup(List<PostToChatterInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }
        
        for (PostToChatterInput input : inputs) {
            if (input != null && input.eventRegistrationId != null && String.isNotBlank(input.activityGroupName)) {
                postEventToChatterGroupInternal(input.eventRegistrationId, input.activityGroupName);
            }
        }
    }
    
    /**
     * Internal method to handle the Chatter post logic
     */
    private static void postEventToChatterGroupInternal(Id eventRegistrationId, String activityGroupName) {
        try {
            // Query the event registration
            List<Event_Registration__c> events = [
                SELECT Id, Name, Activity_Group__c, Start__c, Location__c, 
                       Leader__c, Leader__r.Name
                FROM Event_Registration__c
                WHERE Id = :eventRegistrationId
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                System.debug('Event Registration not found: ' + eventRegistrationId);
                return;
            }
            
            Event_Registration__c event = events[0];
            
            // Find the Chatter group by name
            List<CollaborationGroup> groups = [
                SELECT Id, Name
                FROM CollaborationGroup
                WHERE Name = :activityGroupName
                AND CollaborationType = 'Public'
                LIMIT 1
            ];
            
            if (groups.isEmpty()) {
                System.debug('Chatter group not found: ' + activityGroupName);
                return;
            }
            
            CollaborationGroup targetGroup = groups[0];
            
            // Build the rich text message segments
            ConnectApi.MessageBodyInput messageBodyInput = buildRichTextMessageBody(event);
            
            // Build feed item input
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = targetGroup.Id;
            
            if (!Test.isRunningTest()) {
                // Post to Chatter with rich text formatting
                // Posts as the running user (approver in this case)
                Id networkId = getNetworkId();
                if (networkId == null) {
                    System.debug('ERROR: Could not determine network ID for Chatter posting');
                    return;
                }
                
                ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
                    networkId,
                    feedItemInput
                );
                System.debug('Successfully posted to Chatter group: ' + targetGroup.Name);
            } else {
                // In test context, just verify the logic
                System.debug('Test context: Would post to group ' + targetGroup.Name);
            }
            
        } catch (Exception e) {
            System.debug('Error posting to Chatter group: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw - we don't want to break the flow if Chatter posting fails
        }
    }
    
    /**
     * Builds the rich text message body for a single event Chatter post.
     */
    @TestVisible
    private static ConnectApi.MessageBodyInput buildRichTextMessageBody(Event_Registration__c event) {
        String eventName     = String.isNotBlank(event.Name) ? event.Name : 'Unnamed Event';
        String activityGroup = String.isNotBlank(event.Activity_Group__c) ? event.Activity_Group__c : 'Unknown';
        String startTime     = event.Start__c != null ? formatDateTime(event.Start__c) : 'TBD';
        String location      = String.isNotBlank(event.Location__c) ? event.Location__c : 'Location TBD';
        String eventUrl      = 'https://www.spokanemountaineers.org/s/event-registration/' +
                            (event.Id != null ? String.valueOf(event.Id) : '');

        ConnectApi.MessageBodyInput body = new ConnectApi.MessageBodyInput();
        List<ConnectApi.MessageSegmentInput> segments = new List<ConnectApi.MessageSegmentInput>();

        // Title: **New {Activity Group} Event!**
        addParagraphWithBoldText(segments, 'New ' + activityGroup + ' Event!');

        // Blank line after title
        addSpacerParagraph(segments);

        // Intro line
        addParagraphText(
            segments,
            'A new ' + activityGroup + ' event has been added to the club calendar!'
        );

        // Blank line after intro
        addSpacerParagraph(segments);

        // Event details
        addParagraphWithBoldText(segments, eventName);

        String leaderName = (event.Leader__r != null && String.isNotBlank(event.Leader__r.Name))
            ? event.Leader__r.Name
            : 'TBD';
        addParagraphText(segments, 'Leader: ' + leaderName);
        addParagraphText(segments, 'Start: ' + startTime);

        addParagraphText(segments, 'Location: ' + location);

        // View Event line
        addParagraphText(segments, 'View Event: ' + eventUrl);

        body.messageSegments = segments;
        return body;
    }

    /**
     * Helper: add a paragraph with a single text segment.
     */
    @TestVisible
    private static void addParagraphText(
        List<ConnectApi.MessageSegmentInput> segments,
        String text
    ) {
        ConnectApi.MarkupBeginSegmentInput pBegin = new ConnectApi.MarkupBeginSegmentInput();
        pBegin.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pBegin);

        ConnectApi.TextSegmentInput textSeg = new ConnectApi.TextSegmentInput();
        textSeg.text = text;
        segments.add(textSeg);

        ConnectApi.MarkupEndSegmentInput pEnd = new ConnectApi.MarkupEndSegmentInput();
        pEnd.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pEnd);
    }

    /**
     * Helper: add a paragraph with bold text.
     */
    @TestVisible
    private static void addParagraphWithBoldText(
        List<ConnectApi.MessageSegmentInput> segments,
        String text
    ) {
        ConnectApi.MarkupBeginSegmentInput pBegin = new ConnectApi.MarkupBeginSegmentInput();
        pBegin.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pBegin);

        ConnectApi.MarkupBeginSegmentInput boldBegin = new ConnectApi.MarkupBeginSegmentInput();
        boldBegin.markupType = ConnectApi.MarkupType.Bold;
        segments.add(boldBegin);

        ConnectApi.TextSegmentInput textSeg = new ConnectApi.TextSegmentInput();
        textSeg.text = text;
        segments.add(textSeg);

        ConnectApi.MarkupEndSegmentInput boldEnd = new ConnectApi.MarkupEndSegmentInput();
        boldEnd.markupType = ConnectApi.MarkupType.Bold;
        segments.add(boldEnd);

        ConnectApi.MarkupEndSegmentInput pEnd = new ConnectApi.MarkupEndSegmentInput();
        pEnd.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pEnd);
    }

    
    /**
     * Formats a DateTime for display
     */
    private static String formatDateTime(DateTime dt) {
        if (dt == null) {
            return 'TBD';
        }
        // Simplified format: M/d/yy at h:mma (e.g., "1/22/26 at 7:00AM")
        return dt.format('M/d/yy \'at\' h:mma');
    }
    
    /**
     * Posts a batch of events to a Chatter group as a single message
     * @param activityGroupName The name of the activity group (must match Chatter group name)
     * @param events List of Event_Registration__c records to include in the post
     */
    @TestVisible
    public static void postBatchToChatterGroup(String activityGroupName, List<Event_Registration__c> events) {
        if (String.isBlank(activityGroupName) || events == null || events.isEmpty()) {
            System.debug('Invalid input for batch posting: activityGroupName=' + activityGroupName + ', events size=' + (events != null ? events.size() : 0));
            return;
        }
        
        try {
            // Find the Chatter group by name
            List<CollaborationGroup> groups = [
                SELECT Id, Name
                FROM CollaborationGroup
                WHERE Name = :activityGroupName
                AND CollaborationType = 'Public'
                LIMIT 1
            ];
            
            if (groups.isEmpty()) {
                System.debug('Chatter group not found: ' + activityGroupName);
                return;
            }
            
            CollaborationGroup targetGroup = groups[0];
            
            // Build the rich text message segments for batch
            ConnectApi.MessageBodyInput messageBodyInput = buildBatchRichTextMessageBody(events, activityGroupName);
            
            // Build feed item input
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = targetGroup.Id;
            
            if (!Test.isRunningTest()) {
                // Post to Chatter with rich text formatting
                Id networkId = getNetworkId();
                if (networkId == null) {
                    System.debug('ERROR: Could not determine network ID for Chatter posting to ' + targetGroup.Name);
                    return;
                }
                
                ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
                    networkId,
                    feedItemInput
                );
                System.debug('Successfully posted batch to Chatter group: ' + targetGroup.Name + ' with ' + events.size() + ' events');
            } else {
                // In test context, just verify the logic
                System.debug('Test context: Would post batch to group ' + targetGroup.Name + ' with ' + events.size() + ' events');
            }
            
        } catch (Exception e) {
            System.debug('Error posting batch to Chatter group: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw - continue processing other groups
        }
    }
    
    /**
     * Builds the rich text message body for a batch of events
     * Format:
     *   New {ActivityGroup} Events Added!
     *
     *   We’ve added {N} new {ActivityGroup} events to the club calendar:
     *
     *   Event Name
     *   Leader: ...
     *   Start: ...
     *   Location: ...
     *   View Event: ...
     */
    @TestVisible
    public static ConnectApi.MessageBodyInput buildBatchRichTextMessageBody(
        List<Event_Registration__c> events,
        String activityGroup
    ) {
        if (events == null || events.isEmpty()) {
            return buildRichTextMessageBody(new Event_Registration__c());
        }
    
        // Single event uses existing format
        if (events.size() == 1) {
            return buildRichTextMessageBody(events[0]);
        }
    
        String activityGroupName = String.isNotBlank(activityGroup) ? activityGroup : 'Unknown';
        Integer eventCount = events.size();
    
        ConnectApi.MessageBodyInput body = new ConnectApi.MessageBodyInput();
        List<ConnectApi.MessageSegmentInput> segments = new List<ConnectApi.MessageSegmentInput>();
    
        // Title
        addParagraphWithBoldText(segments, 'New ' + activityGroupName + ' Events Added!');
    
        // Intro line
        addParagraphText(
            segments,
            'We’ve added ' + eventCount + ' new ' + activityGroupName + ' events to the club calendar:'
        );
    
        // *** ADD THIS TO CREATE A BLANK LINE BEFORE FIRST EVENT ***
        addSpacerParagraph(segments);
    
        // Event blocks
        for (Integer i = 0; i < events.size(); i++) {
            Event_Registration__c event = events[i];
    
            String eventName = String.isNotBlank(event.Name) ? event.Name : 'Unnamed Event';
            String startTime = event.Start__c != null ? formatDateTime(event.Start__c) : 'TBD';
            String location  = String.isNotBlank(event.Location__c) ? event.Location__c : 'Location TBD';
            String eventUrl  = 'https://www.spokanemountaineers.org/s/event-registration/' +
                               (event.Id != null ? String.valueOf(event.Id) : '');
    
            String leaderName =
                (event.Leader__r != null && String.isNotBlank(event.Leader__r.Name))
                ? event.Leader__r.Name
                : 'TBD';
    
            // Event title
            addParagraphWithBoldText(segments, eventName);
    
            addParagraphText(segments, 'Leader: ' + leaderName);
            addParagraphText(segments, 'Start: ' + startTime);
            addParagraphText(segments, 'Location: ' + location);
            addParagraphText(segments, 'View Event: ' + eventUrl);
    
            // Spacer between events (except last)
            if (i < events.size() - 1) {
                addSpacerParagraph(segments);
            }
        }
    
        body.messageSegments = segments;
        return body;
    }
    
    
    /**
     * Adds a "blank line" paragraph using a non-breaking space so Chatter
     * will actually render vertical space between event blocks.
     */
    @TestVisible
    private static void addSpacerParagraph(List<ConnectApi.MessageSegmentInput> segments) {
        ConnectApi.MarkupBeginSegmentInput pBegin = new ConnectApi.MarkupBeginSegmentInput();
        pBegin.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pBegin);
    
        ConnectApi.TextSegmentInput spacerText = new ConnectApi.TextSegmentInput();
        spacerText.text = '\u00A0'; // non-breaking space (forces visible blank line)
        segments.add(spacerText);
    
        ConnectApi.MarkupEndSegmentInput pEnd = new ConnectApi.MarkupEndSegmentInput();
        pEnd.markupType = ConnectApi.MarkupType.Paragraph;
        segments.add(pEnd);
    }
    
}
