public with sharing class TicketQueryHelper {
    
    /**
     * Get all Cases for the current Experience Cloud user's Contact
     * @return List of Case records with related data
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getMyTickets() {
        try {
            Id contactId = TicketSubmissionHelper.getContactForUser();
            
            if (contactId == null) {
                return new List<Case>();
            }
            
            return [
                SELECT Id, CaseNumber, Subject, Description, Status, Priority,
                       RecordType.Name, RecordType.DeveloperName,
                       CreatedDate, LastModifiedDate, ClosedDate,
                       Owner.Name, Owner.Type
                FROM Case
                WHERE ContactId = :contactId
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving tickets: ' + e.getMessage());
        }
    }
    
    /**
     * Get a single Case with full details including comments
     * @param caseId Case ID
     * @return Case record with related comments
     */
    @AuraEnabled(cacheable=true)
    public static Case getTicketDetails(String caseId) {
        try {
            // Verify user owns this Case
            Id contactId = TicketSubmissionHelper.getContactForUser();
            
            Case targetCase = [
                SELECT Id, CaseNumber, Subject, Description, Status, Priority,
                       RecordType.Name, RecordType.DeveloperName,
                       CreatedDate, LastModifiedDate, ClosedDate,
                       Owner.Name, Owner.Type,
                       Contact.Name, Contact.Email,
                       Contact.User_Lookup__c, Contact.User_Lookup__r.Name,
                       Related_User__c
                FROM Case
                WHERE Id = :caseId
                AND ContactId = :contactId
                LIMIT 1
            ];
            
            return targetCase;
        } catch (QueryException e) {
            throw new AuraHandledException('Ticket not found or you do not have permission to view it.');
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving ticket details: ' + e.getMessage());
        }
    }
    
    /**
     * Get all public comments for a Case
     * @param caseId Case ID
     * @return List of CaseComment records
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseComment> getTicketComments(String caseId) {
        try {
            // Verify user owns this Case
            Id contactId = TicketSubmissionHelper.getContactForUser();
            
            Case targetCase = [
                SELECT Id, ContactId
                FROM Case
                WHERE Id = :caseId
                AND ContactId = :contactId
                LIMIT 1
            ];
            
            return [
                SELECT Id, CommentBody, CreatedDate, CreatedBy.Name, IsPublished
                FROM CaseComment
                WHERE ParentId = :caseId
                AND IsPublished = true
                ORDER BY CreatedDate ASC
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Ticket not found or you do not have permission to view it.');
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving comments: ' + e.getMessage());
        }
    }
    
    /**
     * Get filtered tickets by status
     * @param statusFilter Status filter (All, Open, Closed)
     * @return List of Case records
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getMyTicketsByStatus(String statusFilter) {
        try {
            Id contactId = TicketSubmissionHelper.getContactForUser();
            
            if (contactId == null) {
                return new List<Case>();
            }
            
            String query = 'SELECT Id, CaseNumber, Subject, Description, Status, Priority, ' +
                          'RecordType.Name, RecordType.DeveloperName, ' +
                          'CreatedDate, LastModifiedDate, ClosedDate, ' +
                          'Owner.Name, Owner.Type ' +
                          'FROM Case ' +
                          'WHERE ContactId = :contactId ';
            
            if (statusFilter == 'Open') {
                query += 'AND Status NOT IN (\'Closed\', \'Resolved\') ';
            } else if (statusFilter == 'Closed') {
                query += 'AND Status IN (\'Closed\', \'Resolved\') ';
            }
            
            query += 'ORDER BY CreatedDate DESC LIMIT 100';
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving tickets: ' + e.getMessage());
        }
    }
}

