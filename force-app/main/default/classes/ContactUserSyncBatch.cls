public class ContactUserSyncBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Integer recordsProcessed = 0;
    private Integer recordsUpdated = 0;
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all Contacts without User lookup that have Email
        return Database.getQueryLocator([
            SELECT Id, Email, User_Lookup__c 
            FROM Contact 
            WHERE Email != null 
            AND User_Lookup__c = null
            LIMIT 50000
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        // Collect emails and transformed values for matching
        Set<String> emails = new Set<String>();
        Set<String> federationIdentifiers = new Set<String>();
        Set<String> usernamesWithSmi = new Set<String>();
        
        for (Contact contact : scope) {
            if (contact.Email != null) {
                emails.add(contact.Email);
                // Transform Email to FederationIdentifier format: replace @ with _, append @spokanemountaineers.org
                federationIdentifiers.add(contact.Email.replace('@', '_') + '@spokanemountaineers.org');
                // Also check for common Username pattern: email.smi
                usernamesWithSmi.add(contact.Email + '.smi');
            }
        }
        
        // Find matching Users with prioritized matching
        Map<String, User> usersByEmail = new Map<String, User>();
        Map<String, User> usersByFederationId = new Map<String, User>();
        Map<String, User> usersByUsername = new Map<String, User>();
        
        for (User user : [
            SELECT Id, Email, FederationIdentifier, Username 
            FROM User 
            WHERE Email IN :emails 
               OR FederationIdentifier IN :federationIdentifiers
               OR Username IN :usernamesWithSmi
        ]) {
            if (user.Email != null) usersByEmail.put(user.Email, user);
            if (user.FederationIdentifier != null) usersByFederationId.put(user.FederationIdentifier, user);
            if (user.Username != null) usersByUsername.put(user.Username, user);
        }
        
        // Update Contacts with matching Users (prioritized matching)
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Contact contact : scope) {
            recordsProcessed++;
            
            if (contact.Email != null) {
                // Prioritized matching: Email > FederationIdentifier > Username
                User matchingUser = usersByEmail.get(contact.Email);
                if (matchingUser == null) {
                    String fedId = contact.Email.replace('@', '_') + '@spokanemountaineers.org';
                    matchingUser = usersByFederationId.get(fedId);
                }
                if (matchingUser == null) {
                    matchingUser = usersByUsername.get(contact.Email + '.smi');
                }
                
                if (matchingUser != null) {
                    contact.User_Lookup__c = matchingUser.Id;
                    contactsToUpdate.add(contact);
                    recordsUpdated++;
                }
            }
        }
        
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Get information about the batch job
        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed,
                TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        // Send summary email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {job.CreatedBy.Email};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Contact-User Sync Batch Status: ' + job.Status);
        
        String body = 'The batch Apex job processed ' + recordsProcessed + ' records.\n\n';
        body += 'Records updated with User lookup: ' + recordsUpdated + '\n\n';
        body += 'Batch job status: ' + job.Status + '\n';
        body += 'Number of errors: ' + job.NumberOfErrors + '\n';
        body += 'Job items processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems;
        
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        System.debug('Contact-User Sync Batch completed. Processed: ' + recordsProcessed + ', Updated: ' + recordsUpdated);
    }
}
