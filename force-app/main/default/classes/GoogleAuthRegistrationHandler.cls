/**
 * Registration Handler for Google OAuth Authentication
 * 
 * Handles user authentication for Google login on Experience Cloud sites.
 * ONLY authenticates existing users - does NOT create new accounts.
 * 
 * IMPORTANT: New accounts must be created through Donorbox integration.
 * This handler will throw an exception if a user attempts to log in with
 * Google before registering through Donorbox.
 * 
 * Matching Logic:
 * - Matches by User.Username = Google email + '.smi' (username pattern only)
 * - Uses username instead of email because:
 *   - Usernames cannot be modified (more reliable)
 *   - Email addresses can be changed by users
 *   - Username always contains the original email address
 * 
 * NOTE: If the '.smi' suffix is removed in the future, update the username
 * pattern matching logic accordingly.
 */
public class GoogleAuthRegistrationHandler implements Auth.RegistrationHandler {
    
    /**
     * Authenticates an existing user for Google OAuth authentication
     * 
     * IMPORTANT: This method does NOT create new users. Users must register
     * through Donorbox first. If no existing user is found, an exception is thrown
     * with actionable guidance for the user.
     * 
     * @param portalId The Network (Experience Cloud site) ID
     * @param data User data from Google OAuth callback
     * @return User record (existing user only)
     * @throws RegistrationHandlerException if no existing user is found
     */
    public User createUser(Id portalId, Auth.UserData data) {
        System.debug('GoogleAuthRegistrationHandler.createUser called for email: ' + data.email);
        System.debug('PortalId: ' + portalId);
        
        // Validate required data
        if (String.isBlank(data.email)) {
            System.debug('ERROR: Email is required but was blank');
            throw new RegistrationHandlerException('Email is required for authentication');
        }
        
        // Match existing user by Email (primary) or Username pattern (secondary)
        User existingUser = findExistingUser(data.email);
        if (existingUser != null) {
            System.debug('Found existing user: ' + existingUser.Id + ' with username: ' + existingUser.Username);
            return existingUser;
        }
        
        // No existing user found - do NOT create new account
        // Provide actionable guidance to the user
        System.debug('ERROR: No existing user found for email: ' + data.email);
        System.debug('User must register through Donorbox before using Google login');
        
        String errorMessage = 'No account found for this email address.\n\n' +
            'If you are a new member, please sign up at:\n' +
            'https://donorbox.org/spokanemountaineers-membership-2\n\n' +
            'If you already have an account, please:\n' +
            '1. Use your usual login method for now\n' +
            '2. Report this issue to webdev@spokanemountaineers.org\n\n' +
            'We will help you link your Google account to your existing membership.';
        
        throw new RegistrationHandlerException(errorMessage);
    }
    
    /**
     * Updates an existing user (not used in this implementation)
     * Existing flows handle user updates automatically
     */
    public void updateUser(Id userId, Id portalId, Auth.UserData data) {
        // No updates needed - existing flows will handle any necessary updates
        System.debug('GoogleAuthRegistrationHandler.updateUser called for userId: ' + userId + ', but no updates needed');
    }
    
    /**
     * Finds an existing user by username pattern only
     * 
     * Uses username pattern (email + '.smi') instead of email matching because:
     * - Usernames cannot be modified (more reliable)
     * - Email addresses can be changed by users
     * - Username always contains the original email address
     * 
     * @param email The email address to match (used to construct username pattern)
     * @return User if found, null otherwise
     */
    @TestVisible
    private User findExistingUser(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        
        // Match by username pattern only (email + '.smi')
        // This is safer than email matching because usernames cannot be modified
        String usernamePattern = email.toLowerCase().trim() + '.smi';
        List<User> usersByUsername = [
            SELECT Id, Username, Email, IsActive
            FROM User
            WHERE Username = :usernamePattern
            LIMIT 1
        ];
        
        if (!usersByUsername.isEmpty()) {
            System.debug('Found user by username pattern: ' + usersByUsername[0].Username);
            return usersByUsername[0];
        }
        
        return null;
    }
    
    /**
     * Gets profile ID from Network (Experience Cloud site)
     * 
     * @param portalId The Network ID
     * @return Profile ID for new users
     */
    @TestVisible
    private Id getProfileIdFromNetwork(Id portalId) {
        try {
            // Query Network to verify it exists
            List<Network> networks = [
                SELECT Id
                FROM Network
                WHERE Id = :portalId
                LIMIT 1
            ];
            
            if (networks.isEmpty()) {
                System.debug('ERROR: Network not found for portalId: ' + portalId);
                return null;
            }
            
            // For Experience Cloud sites, query for Customer Community profiles
            // These are typically used for Experience Cloud users
            List<Profile> profiles = [
                SELECT Id
                FROM Profile
                WHERE UserType IN ('CspLitePortal', 'PowerCustomerSuccess', 'PowerPartner')
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            
            if (!profiles.isEmpty()) {
                return profiles[0].Id;
            }
            
            System.debug('WARNING: No Customer Community profile found, this may cause issues');
            return null;
        } catch (Exception e) {
            System.debug('ERROR retrieving profile from network: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * Creates a new user with the .smi username pattern
     * 
     * @param data User data from Google OAuth
     * @param profileId Profile ID for new user
     * @return Newly created User
     */
    @TestVisible
    private User createNewUser(Auth.UserData data, Id profileId) {
        String email = data.email.toLowerCase().trim();
        String username = email + '.smi';
        
        // Check for duplicate username and append suffix if needed
        username = ensureUniqueUsername(username);
        
        // Generate alias (first 8 chars of email before @)
        String alias = generateAlias(email);
        
        // Create user
        User newUser = new User(
            Username = username,
            Email = email,
            FirstName = String.isNotBlank(data.firstName) ? data.firstName : null,
            LastName = String.isNotBlank(data.lastName) ? data.lastName : 'User',
            Alias = alias,
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        
        // Generate a random password (Salesforce will require password reset on first login)
        String randomPassword = generateRandomPassword();
        
        try {
            // Insert user with password
            insert newUser;
            
            // Set password separately (requires System.runAs or special permissions)
            System.setPassword(newUser.Id, randomPassword);
            
            System.debug('Successfully created user: ' + newUser.Id);
            return newUser;
        } catch (DmlException e) {
            System.debug('ERROR creating user: ' + e.getMessage());
            System.debug('DML Exception fields: ' + e.getDmlFieldNames(0));
            System.debug('DML Exception status code: ' + e.getDmlType(0));
            throw new RegistrationHandlerException('Failed to create user: ' + e.getMessage());
        }
    }
    
    /**
     * Ensures username is unique by appending a suffix if needed
     * 
     * @param baseUsername The base username (email.smi)
     * @return Unique username
     */
    @TestVisible
    private String ensureUniqueUsername(String baseUsername) {
        // Check if username already exists
        List<User> existingUsers = [
            SELECT Id
            FROM User
            WHERE Username = :baseUsername
            LIMIT 1
        ];
        
        if (existingUsers.isEmpty()) {
            return baseUsername;
        }
        
        // Username exists, append a short suffix
        Integer suffix = 1;
        String uniqueUsername;
        do {
            uniqueUsername = baseUsername + String.valueOf(suffix);
            existingUsers = [
                SELECT Id
                FROM User
                WHERE Username = :uniqueUsername
                LIMIT 1
            ];
            suffix++;
            // Safety check to prevent infinite loop
            if (suffix > 1000) {
                System.debug('ERROR: Could not generate unique username after 1000 attempts');
                throw new RegistrationHandlerException('Could not generate unique username');
            }
        } while (!existingUsers.isEmpty());
        
        System.debug('Username collision detected, using: ' + uniqueUsername);
        return uniqueUsername;
    }
    
    /**
     * Generates an alias from email (first 8 chars before @)
     * 
     * @param email The email address
     * @return Alias (max 8 characters)
     */
    @TestVisible
    private String generateAlias(String email) {
        if (String.isBlank(email)) {
            return 'user';
        }
        
        Integer atIndex = email.indexOf('@');
        if (atIndex > 0) {
            String alias = email.substring(0, atIndex);
            // Limit to 8 characters (Salesforce requirement)
            return alias.length() > 8 ? alias.substring(0, 8) : alias;
        }
        
        // Fallback if no @ found
        return email.length() > 8 ? email.substring(0, 8) : email;
    }
    
    
    /**
     * Generates a random password for new users
     * 
     * @return Random password string
     */
    @TestVisible
    private String generateRandomPassword() {
        // Generate a random password that meets Salesforce requirements
        // Must be at least 8 characters, contain uppercase, lowercase, number, and special character
        String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        String lowercase = 'abcdefghijklmnopqrstuvwxyz';
        String numbers = '0123456789';
        String special = '!@#$%^&*';
        String chars = uppercase + lowercase + numbers + special;
        String password = '';
        Integer length = 12;
        
        // Ensure at least one of each required character type
        Integer upperIdx = Math.mod(Integer.valueOf(Math.random() * 1000), uppercase.length());
        password += uppercase.substring(upperIdx, upperIdx + 1);
        
        Integer lowerIdx = Math.mod(Integer.valueOf(Math.random() * 1000), lowercase.length());
        password += lowercase.substring(lowerIdx, lowerIdx + 1);
        
        Integer numIdx = Math.mod(Integer.valueOf(Math.random() * 1000), numbers.length());
        password += numbers.substring(numIdx, numIdx + 1);
        
        Integer specialIdx = Math.mod(Integer.valueOf(Math.random() * 1000), special.length());
        password += special.substring(specialIdx, specialIdx + 1);
        
        // Fill the rest randomly
        for (Integer i = password.length(); i < length; i++) {
            Integer charIdx = Math.mod(Integer.valueOf(Math.random() * 1000), chars.length());
            password += chars.substring(charIdx, charIdx + 1);
        }
        
        return password;
    }
    
    /**
     * Custom exception for Registration Handler errors
     */
    public class RegistrationHandlerException extends Exception {}
}

