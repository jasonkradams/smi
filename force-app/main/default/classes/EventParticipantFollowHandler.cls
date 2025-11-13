public with sharing class EventParticipantFollowHandler {
    @TestVisible
    private static Map<Id, Event_Registration__c> testRegById;

    @TestVisible
    private static Map<Id, Contact> testContactById;

    @TestVisible
    private static Id testNetworkId;

    // Public entry for trigger
    public static void handleAfterInsert(List<Event_Participant__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Id currentNetworkId = null;
        if (Test.isRunningTest() && testNetworkId != null) {
            currentNetworkId = testNetworkId;
        } else {
            try {
                currentNetworkId = Network.getNetworkId();
            } catch (Exception e) {
                // ignore: NetworkId only available for community contexts
            }
        }

        // Query needed relationships in bulk
        Set<Id> registrationIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Event_Participant__c ep : newRecords) {
            if (ep.Event_Registration__c != null) {
                registrationIds.add(ep.Event_Registration__c);
            }
            if (ep.Contact__c != null) {
                contactIds.add(ep.Contact__c);
            }
        }
        Map<Id, Event_Registration__c> regById = new Map<Id, Event_Registration__c>();
        if (!registrationIds.isEmpty()) {
            if (Test.isRunningTest() && testRegById != null) {
                regById = new Map<Id, Event_Registration__c>();
                for (Id regId : registrationIds) {
                    if (testRegById.containsKey(regId)) {
                        regById.put(regId, testRegById.get(regId));
                    }
                }
            } else {
                regById = new Map<Id, Event_Registration__c>([
                    SELECT Id
                    FROM Event_Registration__c
                    WHERE Id IN :registrationIds
                ]);
            }
        }

        Map<Id, Contact> contactById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            if (Test.isRunningTest() && testContactById != null) {
                contactById = new Map<Id, Contact>();
                for (Id contactId : contactIds) {
                    if (testContactById.containsKey(contactId)) {
                        contactById.put(contactId, testContactById.get(contactId));
                    }
                }
            } else {
                contactById = new Map<Id, Contact>([
                    SELECT Id, User_Lookup__c
                    FROM Contact
                    WHERE Id IN :contactIds
                ]);
            }
        }

        // Collect candidate subscriptions
        List<EntitySubscription> toInsert = new List<EntitySubscription>();
        // Build a set to de-dupe within this transaction
        Set<String> uniquePairs = new Set<String>();

        for (Event_Participant__c ep : newRecords) {
            Event_Registration__c er = regById.get(ep.Event_Registration__c);
            Contact c = contactById.get(ep.Contact__c);

            // Subscriber: Contact.User_Lookup__c must be populated
            Id subscriberId = (c != null) ? c.User_Lookup__c : null;

            if (er == null || subscriberId == null) {
                continue; // skip when missing either side
            }

            // De-dupe using composite key
            Id parentId = er.Id;
            String networkKey = (currentNetworkId != null) ? (String)currentNetworkId : 'null';
            String key = (String)parentId + ':' + (String)subscriberId + ':' + networkKey;
            if (!uniquePairs.add(key)) {
                continue;
            }

            EntitySubscription es = new EntitySubscription();
            es.ParentId = parentId;
            es.SubscriberId = subscriberId;
            es.NetworkId = currentNetworkId;
            toInsert.add(es);
        }

        if (toInsert.isEmpty()) return;

        // Further de-dupe vs existing subscriptions in org to avoid duplicate DML errors
        // Query existing EntitySubscriptions for these pairs
        Set<Id> parentIds = new Set<Id>();
        Set<Id> subscriberIds = new Set<Id>();
        for (EntitySubscription es : toInsert) {
            parentIds.add(es.ParentId);
            subscriberIds.add(es.SubscriberId);
        }

        Map<String, Boolean> existing = new Map<String, Boolean>();
        List<EntitySubscription> existingSubs;
        if (currentNetworkId == null) {
            existingSubs = [
                SELECT Id, ParentId, SubscriberId, NetworkId
                FROM EntitySubscription
                WHERE ParentId IN :parentIds
                  AND SubscriberId IN :subscriberIds
                  AND NetworkId = null
                LIMIT 1000
            ];
        } else {
            existingSubs = [
                SELECT Id, ParentId, SubscriberId, NetworkId
                FROM EntitySubscription
                WHERE ParentId IN :parentIds
                  AND SubscriberId IN :subscriberIds
                  AND NetworkId = :currentNetworkId
                LIMIT 1000
            ];
        }
        for (EntitySubscription esExisting : existingSubs) {
            String networkKey = (esExisting.NetworkId != null) ? (String)esExisting.NetworkId : 'null';
            existing.put((String)esExisting.ParentId + ':' + (String)esExisting.SubscriberId + ':' + networkKey, true);
        }

        List<EntitySubscription> finalInserts = new List<EntitySubscription>();
        for (EntitySubscription es : toInsert) {
            String networkKey = (es.NetworkId != null) ? (String)es.NetworkId : 'null';
            String key = (String)es.ParentId + ':' + (String)es.SubscriberId + ':' + networkKey;
            if (!existing.containsKey(key)) {
                finalInserts.add(es);
            }
        }

        if (finalInserts.isEmpty()) return;

        // Insert with partial success
        Database.SaveResult[] results = Database.insert(finalInserts, /* allOrNone */ false);
        // Optionally log errors to debug
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(LoggingLevel.WARN, 'EntitySubscription insert failed: ' + err.getStatusCode() + ' - ' + err.getMessage());
                }
            }
        }
    }
}
