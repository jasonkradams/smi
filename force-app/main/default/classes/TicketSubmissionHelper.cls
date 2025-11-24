public with sharing class TicketSubmissionHelper {
    
    /**
     * Get the Contact record associated with the current Experience Cloud user
     * @return Contact ID or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static Id getContactForUser() {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            // Query for User record to get Contact ID
            User currentUser = [
                SELECT Id, ContactId 
                FROM User 
                WHERE Id = :currentUserId 
                LIMIT 1
            ];
            
            // If User has ContactId, return it
            if (currentUser.ContactId != null) {
                return currentUser.ContactId;
            }
            
            // If User doesn't have ContactId, try to find Contact by email
            String userEmail = [
                SELECT Email 
                FROM User 
                WHERE Id = :currentUserId 
                LIMIT 1
            ].Email;
            
            if (String.isNotBlank(userEmail)) {
                List<Contact> contacts = [
                    SELECT Id 
                    FROM Contact 
                    WHERE Email = :userEmail 
                    LIMIT 1
                ];
                
                if (!contacts.isEmpty()) {
                    return contacts[0].Id;
                }
            }
            
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Contact: ' + e.getMessage());
        }
    }
    
    /**
     * Get available Case Record Types for ticket submission
     * @return List of RecordType wrapper objects with Id, Label, and DeveloperName
     */
    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getRecordTypes() {
        try {
            List<RecordType> recordTypes = [
                SELECT Id, Name, DeveloperName, Description
                FROM RecordType
                WHERE SObjectType = 'Case'
                AND IsActive = true
                AND DeveloperName IN ('Technical_Bug', 'Feature_Request', 'Account_Access', 'General_Feedback')
                ORDER BY Name
            ];
            
            List<RecordTypeOption> options = new List<RecordTypeOption>();
            for (RecordType rt : recordTypes) {
                RecordTypeOption option = new RecordTypeOption();
                option.value = rt.Id;
                option.label = rt.Name;
                option.description = rt.Description;
                options.add(option);
            }
            
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving record types: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper class for RecordType options
     */
    public class RecordTypeOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
    }
    
    /**
     * Create a new Case record from Experience Cloud
     * @param subject Case subject
     * @param description Case description
     * @param recordTypeId Case record type ID
     * @param priority Case priority (optional)
     * @return Case record with Case Number
     */
    @AuraEnabled
    public static Case createCase(String subject, String description, String recordTypeId, String priority) {
        try {
            // Validate required fields
            if (String.isBlank(subject)) {
                throw new AuraHandledException('Subject is required.');
            }
            if (String.isBlank(description) || description.length() < 10) {
                throw new AuraHandledException('Description is required and must be at least 10 characters.');
            }
            if (String.isBlank(recordTypeId)) {
                throw new AuraHandledException('Ticket type is required.');
            }
            
            // Get Contact for current user
            Id contactId = getContactForUser();
            if (contactId == null) {
                throw new AuraHandledException('Unable to find Contact record. Please ensure you are logged in with a valid member account.');
            }
            
            // Determine default queue based on record type
            Id ownerId = getDefaultQueueForRecordType(recordTypeId);
            
            // Create Case record
            Case newCase = new Case();
            newCase.Subject = subject;
            newCase.Description = description;
            newCase.RecordTypeId = recordTypeId;
            newCase.ContactId = contactId;
            newCase.Origin = 'Web';
            newCase.OwnerId = ownerId != null ? ownerId : UserInfo.getUserId();
            
            // Set priority if provided
            if (String.isNotBlank(priority)) {
                newCase.Priority = priority;
            }
            
            // Insert Case
            insert newCase;
            
            // Query back to get Case Number
            return [
                SELECT Id, CaseNumber, Subject, Status, Priority, RecordType.Name, CreatedDate
                FROM Case
                WHERE Id = :newCase.Id
                LIMIT 1
            ];
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve the original message
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating ticket: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error creating ticket: ' + e.getMessage());
        }
    }
    
    /**
     * Add a public comment to an existing Case
     * @param caseId Case ID
     * @param commentBody Comment text
     * @return CaseComment record
     */
    @AuraEnabled
    public static CaseComment addComment(String caseId, String commentBody) {
        try {
            // Validate inputs
            if (String.isBlank(caseId)) {
                throw new AuraHandledException('Case ID is required.');
            }
            if (String.isBlank(commentBody)) {
                throw new AuraHandledException('Comment is required.');
            }
            
            // Verify user owns this Case
            Id contactId = getContactForUser();
            if (contactId == null) {
                throw new AuraHandledException('Unable to find Contact record. Please ensure you are logged in with a valid member account.');
            }
            
            Case targetCase = [
                SELECT Id, ContactId, Status
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (targetCase.ContactId != contactId) {
                throw new AuraHandledException('You do not have permission to add comments to this ticket.');
            }
            
            // Check if Case is closed
            if (targetCase.Status == 'Closed' || targetCase.Status == 'Resolved') {
                throw new AuraHandledException('Cannot add comments to closed or resolved tickets.');
            }
            
            // Create Case Comment
            CaseComment comment = new CaseComment();
            comment.ParentId = caseId;
            comment.CommentBody = commentBody;
            comment.IsPublished = true; // Public comment visible to member
            
            insert comment;
            
            return comment;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve the original message
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Error adding comment: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error adding comment: ' + e.getMessage());
        }
    }
    
    /**
     * Get default queue ID for a given record type
     * @param recordTypeId Record type ID
     * @return Queue ID or null if not found
     */
    private static Id getDefaultQueueForRecordType(String recordTypeId) {
        try {
            // Get record type name
            RecordType rt = [
                SELECT Id, Name, DeveloperName
                FROM RecordType
                WHERE Id = :recordTypeId
                LIMIT 1
            ];
            
            // Map record types to queue names
            String queueName = null;
            if (rt.DeveloperName == 'Technical_Bug' || rt.DeveloperName == 'Account_Access') {
                queueName = 'Technical Support Queue';
            } else if (rt.DeveloperName == 'Feature_Request' || rt.DeveloperName == 'General_Feedback') {
                queueName = 'Product Feedback Queue';
            }
            
            if (String.isNotBlank(queueName)) {
                // Query for queue
                List<Group> queues = [
                    SELECT Id
                    FROM Group
                    WHERE Type = 'Queue'
                    AND Name = :queueName
                    LIMIT 1
                ];
                
                if (!queues.isEmpty()) {
                    return queues[0].Id;
                }
            }
            
            return null;
        } catch (Exception e) {
            // If queue lookup fails, return null (Case will use current user as owner)
            return null;
        }
    }
}

