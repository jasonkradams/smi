// Trigger: EventParticipantTrigger.trigger
// Purpose: When Event_Participant__c is inserted, auto-subscribe the related User to the parent Event (or other record)
// Mechanism: Creates FeedSubscription(ParentId, SubscriberId)
// ParentId source: Event_Participant__c.Event_Registration__r.Parent_Event_Id__c (Text containing a 15/18-char Salesforce Id)
// SubscriberId source: Event_Participant__c.Contact__r.User_Lookup__c (Lookup(User))
// Notes:
// - Skips when Parent_Event_Id__c is blank/invalid or Contact.User_Lookup__c is null
// - Bulk-safe: delegates to handler
// - Duplicate-safe: handler de-duplicates

trigger EventParticipantTrigger on Event_Participant__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        EventParticipantFollowHandler.handleAfterInsert(Trigger.new);
    }
}
