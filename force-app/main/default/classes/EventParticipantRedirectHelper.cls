public class EventParticipantRedirectHelper {
    @testVisible static Boolean TEST_SIMULATE_EVENT_REG = false;
    @testVisible static String TEST_RELATED_EVENT_ID = null;
    @testVisible static List<Event_Registration__c> TEST_FAKE_REGS = null;
    
    @AuraEnabled
    public static String getUserRedirectUrl(String eventRelationId) {
        try {
            // Query the Event Participant with related Contact and User using TYPEOF for polymorphic relationship
            EventRelation eventRelation = [
                SELECT RelationId, 
                       TYPEOF Relation 
                           WHEN Contact THEN Name, Email, User_Lookup__c, User_Lookup__r.Username
                           ELSE Name, Email
                       END
                FROM EventRelation 
                WHERE Id = :eventRelationId
                LIMIT 1
            ];
            
            // Check if related User exists (only for Contacts)
            if (eventRelation.Relation instanceof Contact) {
                Contact contact = (Contact)eventRelation.Relation;
                if (contact.User_Lookup__c != null) {
                    return '/s/profile/' + contact.User_Lookup__c;
                }
            }
            
            return null; // No related User found or not a Contact
        } catch (Exception e) {
            System.debug('Error getting user redirect URL: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static List<ParticipantWrapper> getEventParticipants(String eventId) {
        try {
            System.debug('EventParticipantRedirectHelper.getEventParticipants called with eventId: ' + eventId);
            
            // First check if this is an Event_Registration__c ID or Event ID
            // Start with a simple query to see what fields exist
            List<Event_Registration__c> eventRegs = [SELECT Id, Name, Status__c 
                                                   FROM Event_Registration__c WHERE Id = :eventId LIMIT 1];
            // Test seam: allow simulating the presence of an Event_Registration__c without DML
            if (Test.isRunningTest() && TEST_SIMULATE_EVENT_REG && eventRegs.isEmpty()) {
                Event_Registration__c fakeReg = new Event_Registration__c();
                fakeReg.Name = 'Test Registration';
                fakeReg.Status__c = 'Registered';
                eventRegs.add(fakeReg);
            }
            
            List<ParticipantWrapper> participants = new List<ParticipantWrapper>();
            
            if (!eventRegs.isEmpty()) {
                System.debug('Found Event_Registration__c record: ' + eventRegs[0].Name);
                
                // Query Event_Participant__c records related to this Event_Registration__c
                // Event_Participant__c has the Contact__c lookup field
                List<Event_Participant__c> eventParticipants = [
                    SELECT Id, Contact__c, Contact__r.Name, Contact__r.Email, Contact__r.User_Lookup__c, 
                           Response__c, Event_Registration__c
                    FROM Event_Participant__c 
                    WHERE Event_Registration__c = :eventId
                    ORDER BY Contact__r.Name
                ];
                
                System.debug('Found ' + eventParticipants.size() + ' Event_Participant__c records');
                
                if (!eventParticipants.isEmpty()) {
                    // Process each participant
                    for (Event_Participant__c participant : eventParticipants) {
                        ParticipantWrapper wrapper = new ParticipantWrapper();
                        wrapper.eventRelationId = participant.Id;
                        
                        if (participant.Contact__c != null) {
                            wrapper.contactId = participant.Contact__c;
                            wrapper.contactName = participant.Contact__r.Name;
                            wrapper.contactEmail = participant.Contact__r.Email;
                            wrapper.userId = participant.Contact__r.User_Lookup__c;
                            wrapper.hasUser = (participant.Contact__r.User_Lookup__c != null);
                            wrapper.status = 'Registered';
                            wrapper.response = participant.Response__c != null ? participant.Response__c : 'Event Registration';
                            
                            participants.add(wrapper);
                            System.debug('Added participant: ' + wrapper.contactName + ' (User: ' + wrapper.hasUser + ', UserId: ' + wrapper.userId + ')');
                        } else {
                            // Participant without Contact - skip or handle differently
                            System.debug('Skipping participant without Contact: ' + participant.Id);
                        }
                    }
                } else {
                    // No Event_Participant__c records found - fallback to Event_Registration__c name
                    System.debug('No Event_Participant__c records found, using Event_Registration__c as fallback');
                    ParticipantWrapper wrapper = new ParticipantWrapper();
                    wrapper.eventRelationId = eventRegs[0].Id;
                    wrapper.contactId = null;
                    wrapper.contactName = eventRegs[0].Name;
                    wrapper.contactEmail = null;
                    wrapper.userId = null;
                    wrapper.hasUser = false;
                    wrapper.status = eventRegs[0].Status__c != null ? eventRegs[0].Status__c : 'Registered';
                    wrapper.response = 'Event Registration';
                    
                    participants.add(wrapper);
                    System.debug('Added single participant (Event_Registration__c): ' + wrapper.contactName);
                }
            } else {
                System.debug('Not an Event_Registration__c, using original EventRelation logic');
                
                // Original EventRelation logic for tests and standard functionality
                List<Event> events = [SELECT Id, Subject, WhoId, WhatId FROM Event WHERE Id = :eventId];
                System.debug('Found events: ' + events.size());
                
                // Check all EventRelations for this Event
                List<EventRelation> allRelations = [SELECT Id, EventId, RelationId, Status, Response FROM EventRelation WHERE EventId = :eventId];
                System.debug('Total EventRelations found: ' + allRelations.size());
                
                if (allRelations.isEmpty() && !events.isEmpty()) {
                    // Try using WhoId (primary person related to the event)
                    Event evt = events[0];
                    if (evt.WhoId != null) {
                        System.debug('Trying WhoId approach: ' + evt.WhoId);
                        // Query the WhoId record (could be Contact or Lead)
                        try {
                            SObject whoRecord = [SELECT Id, Name, Email FROM Contact WHERE Id = :evt.WhoId LIMIT 1];
                            if (whoRecord != null) {
                                ParticipantWrapper wrapper = new ParticipantWrapper();
                                wrapper.eventRelationId = evt.Id; // Use Event ID as fallback
                                wrapper.contactId = whoRecord.Id;
                                wrapper.contactName = String.valueOf(whoRecord.get('Name'));
                                wrapper.contactEmail = String.valueOf(whoRecord.get('Email'));
                                
                                // Check if this Contact has a User lookup
                                Contact contact = [SELECT User_Lookup__c FROM Contact WHERE Id = :whoRecord.Id];
                                wrapper.userId = contact.User_Lookup__c;
                                wrapper.hasUser = (contact.User_Lookup__c != null);
                                wrapper.status = 'Related';
                                wrapper.response = 'Primary Contact';
                                
                                participants.add(wrapper);
                                System.debug('Added participant from WhoId: ' + wrapper.contactName);
                            }
                        } catch (Exception e) {
                            System.debug('WhoId is not a Contact or query failed: ' + e.getMessage());
                        }
                    }
                } else {
                    // Original EventRelation approach
                    for (EventRelation er : [
                        SELECT Id, RelationId, Status, Response,
                               TYPEOF Relation 
                                   WHEN Contact THEN Name, Email, User_Lookup__c
                                   ELSE Name, Email
                               END
                        FROM EventRelation 
                        WHERE EventId = :eventId
                        AND RelationId != null
                        ORDER BY Relation.Name
                    ]) {
                        System.debug('Processing EventRelation: ' + er.Id + ', RelationId: ' + er.RelationId);
                        ParticipantWrapper wrapper = new ParticipantWrapper();
                        wrapper.eventRelationId = er.Id;
                        wrapper.contactId = er.RelationId;
                        
                        // Handle polymorphic relationship
                        if (er.Relation instanceof Contact) {
                            Contact contact = (Contact)er.Relation;
                            wrapper.contactName = contact.Name;
                            wrapper.contactEmail = contact.Email;
                            wrapper.userId = contact.User_Lookup__c;
                            wrapper.hasUser = (contact.User_Lookup__c != null);
                        } else {
                            wrapper.contactName = er.Relation.Name;
                            wrapper.contactEmail = er.Relation.Email;
                            wrapper.userId = null;
                            wrapper.hasUser = false;
                        }
                        
                        wrapper.status = er.Status;
                        wrapper.response = er.Response;
                        
                        participants.add(wrapper);
                    }
                }
            }
            
            System.debug('Returning participants: ' + participants.size());
            return participants;
        } catch (Exception e) {
            System.debug('Error in getEventParticipants: ' + e.getMessage());
            throw new AuraHandledException('Unable to load event participants: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean syncContactToUser(String contactId) {
        try {
            // Get Contact record with Email
            Contact contact = [
                SELECT Id, Email, User_Lookup__c 
                FROM Contact 
                WHERE Id = :contactId
                LIMIT 1
            ];
            
            // If User lookup already exists, no need to sync
            if (contact.User_Lookup__c != null) {
                return true;
            }
            
            // Find matching User with prioritized matching:
            // 1. Contact.Email = User.Email (most reliable)
            // 2. Contact.Email (transformed) = User.FederationIdentifier
            // 3. Contact.Email + '.smi' = User.Username (common pattern)
            String fedId = contact.Email.replace('@', '_') + '@spokanemountaineers.org';
            String usernameWithSmi = contact.Email + '.smi';
            
            List<User> matchingUsers = [
                SELECT Id, Email, FederationIdentifier, Username
                FROM User 
                WHERE Email = :contact.Email
                   OR FederationIdentifier = :fedId
                   OR Username = :usernameWithSmi
                ORDER BY Email ASC, FederationIdentifier ASC, Username ASC
                LIMIT 1
            ];
            
            if (!matchingUsers.isEmpty()) {
                // Update Contact with User lookup
                contact.User_Lookup__c = matchingUsers[0].Id;
                update contact;
                return true;
            }
            
            return false; // No matching User found
        } catch (Exception e) {
            System.debug('Error syncing contact to user: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static List<SyncResult> bulkSyncContactsToUsers(List<String> contactIds) {
        // Efficient bulk sync method that minimizes SOQL queries
        // Prioritized matching:
        // 1. Contact.Email = User.Email (most reliable)
        // 2. Contact.Email (transformed) = User.FederationIdentifier
        // 3. Contact.Email + '.smi' = User.Username (common pattern)
        // Reduces from ~3 queries per contact to just 2 total queries
        
        try {
            // Single query to get all contacts with Email
            Map<Id, Contact> contacts = new Map<Id, Contact>([
                SELECT Id, Email, User_Lookup__c 
                FROM Contact 
                WHERE Id = :contactIds
            ]);
            
            // Collect all unique emails and transformed values for user lookup
            Set<String> emails = new Set<String>();
            Set<String> federationIdentifiers = new Set<String>();
            Set<String> usernamesWithSmi = new Set<String>();
            
            for (Contact c : contacts.values()) {
                if (c.Email != null) {
                    emails.add(c.Email);
                    // Transform Email to FederationIdentifier format: replace @ with _, append @spokanemountaineers.org
                    federationIdentifiers.add(c.Email.replace('@', '_') + '@spokanemountaineers.org');
                    // Also check for common Username pattern: email.smi
                    usernamesWithSmi.add(c.Email + '.smi');
                }
            }
            
            // Single query to get all potential matching users
            Map<String, User> usersByEmail = new Map<String, User>();
            Map<String, User> usersByFederationId = new Map<String, User>();
            Map<String, User> usersByUsername = new Map<String, User>();
            
            if (!emails.isEmpty()) {
                for (User u : [SELECT Id, Email, FederationIdentifier, Username 
                               FROM User 
                               WHERE Email IN :emails 
                               OR FederationIdentifier IN :federationIdentifiers
                               OR Username IN :usernamesWithSmi]) {
                    if (u.Email != null) usersByEmail.put(u.Email, u);
                    if (u.FederationIdentifier != null) usersByFederationId.put(u.FederationIdentifier, u);
                    if (u.Username != null) usersByUsername.put(u.Username, u);
                }
            }
            
            // Process matches in memory with prioritized matching
            List<Contact> toUpdate = new List<Contact>();
            Set<Id> successfullySynced = new Set<Id>();
            
            for (Contact c : contacts.values()) {
                if (c.User_Lookup__c != null) {
                    // Already synced
                    successfullySynced.add(c.Id);
                    continue;
                }
                
                if (c.Email == null) {
                    // No email to match
                    continue;
                }
                
                // Prioritized matching: Email > FederationIdentifier > Username
                User matchUser = usersByEmail.get(c.Email);
                if (matchUser == null) {
                    String fedId = c.Email.replace('@', '_') + '@spokanemountaineers.org';
                    matchUser = usersByFederationId.get(fedId);
                }
                if (matchUser == null) {
                    matchUser = usersByUsername.get(c.Email + '.smi');
                }
                
                if (matchUser != null) {
                    c.User_Lookup__c = matchUser.Id;
                    toUpdate.add(c);
                    successfullySynced.add(c.Id);
                }
            }
            
            // Single bulk update
            if (!toUpdate.isEmpty()) {
                update toUpdate;
                System.debug('Bulk sync updated ' + toUpdate.size() + ' contacts');
            }
            
            // Return comprehensive results
            List<SyncResult> results = new List<SyncResult>();
            for (Id contactId : contactIds) {
                SyncResult r = new SyncResult();
                r.contactId = contactId;
                r.success = successfullySynced.contains(contactId);
                results.add(r);
            }
            
            return results;
            
        } catch (Exception e) {
            System.debug('Error in bulk sync: ' + e.getMessage());
            // Return failure results for all contacts
            List<SyncResult> results = new List<SyncResult>();
            for (Id contactId : contactIds) {
                SyncResult r = new SyncResult();
                r.contactId = contactId;
                r.success = false;
                results.add(r);
            }
            return results;
        }
    }
    
    @InvocableMethod(label='Sync Contacts to Users' description='Batch sync Contacts to matching User records')
    public static List<SyncResult> syncContactsToUsers(List<SyncRequest> requests) {
        List<SyncResult> results = new List<SyncResult>();
        
        for (SyncRequest request : requests) {
            SyncResult result = new SyncResult();
            result.contactId = request.contactId;
            result.success = syncContactToUser(request.contactId);
            results.add(result);
        }
        
        return results;
    }
    
    public class SyncRequest {
        @InvocableVariable(required=true)
        public String contactId;
    }
    
    public class SyncResult {
        @InvocableVariable
        public String contactId;
        
        @InvocableVariable
        public Boolean success;
    }

    public class ParticipantWrapper {
        @AuraEnabled
        public String eventRelationId;
        
        @AuraEnabled
        public String contactId;
        
        @AuraEnabled
        public String contactName;
        
        @AuraEnabled
        public String contactEmail;
        
        @AuraEnabled
        public String userId;
        
        @AuraEnabled
        public Boolean hasUser;
        
        @AuraEnabled
        public String status;
        
        @AuraEnabled
        public String response;
    }
}
