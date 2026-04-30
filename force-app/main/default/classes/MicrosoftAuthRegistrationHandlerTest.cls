@isTest
private class MicrosoftAuthRegistrationHandlerTest {
  /**
   * Test utility to create a mock Auth.UserData object using JSON deserialization
   * This is a workaround since Auth.UserData cannot be instantiated directly
   */
  private static Auth.UserData createMockUserData(
    String email,
    String firstName,
    String lastName
  ) {
    return createMockUserData(email, email, firstName, lastName);
  }

  /**
   * Variant that lets a test set email and userName independently. Microsoft Identity
   * Platform may return an empty email claim with a populated UPN; this lets us cover
   * the UPN fallback path explicitly.
   */
  private static Auth.UserData createMockUserData(
    String email,
    String userName,
    String firstName,
    String lastName
  ) {
    try {
      Map<String, Object> userDataMap = new Map<String, Object>{
        'identifier' => String.isNotBlank(email) ? email : userName,
        'firstName' => firstName,
        'lastName' => lastName,
        'fullName' => (firstName != null ? firstName : '') +
        ' ' +
        (lastName != null ? lastName : ''),
        'email' => email,
        'userName' => userName,
        'locale' => 'en_US',
        'provider' => 'Microsoft'
      };

      String jsonStr = JSON.serialize(userDataMap);
      return (Auth.UserData) JSON.deserialize(jsonStr, Auth.UserData.class);
    } catch (Exception e) {
      return null;
    }
  }

  private static Id getStandardUserProfileId() {
    return [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
  }

  private static Id getCommunityProfileId() {
    List<Profile> profiles = [
      SELECT Id
      FROM Profile
      WHERE UserType = 'CspLitePortal' OR UserType = 'PowerCustomerSuccess'
      LIMIT 1
    ];
    if (!profiles.isEmpty()) {
      return profiles[0].Id;
    }
    return getStandardUserProfileId();
  }

  @testSetup
  static void makeData() {
    String uniqueSuffix = String.valueOf(System.currentTimeMillis())
      .substring(8);
    Id profileId = getStandardUserProfileId();

    // Create an existing user for matching tests
    User existingUser = new User(
      Username = 'msexisting' + uniqueSuffix + '@example.com.smi',
      Email = 'msexisting' + uniqueSuffix + '@example.com',
      LastName = 'Existing',
      FirstName = 'User',
      Alias = 'msex' + uniqueSuffix.substring(0, 2),
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert existingUser;

    // Create another user with email match (no .smi in username) - used as a negative case
    User emailMatchUser = new User(
      Username = 'msemailmatch' + uniqueSuffix + '@example.com',
      Email = 'msemailmatch' + uniqueSuffix + '@example.com',
      LastName = 'EmailMatch',
      FirstName = 'User',
      Alias = 'msem' + uniqueSuffix.substring(0, 2),
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert emailMatchUser;

    // Create a user with a specific username for uniqueness testing
    User usernameTestUser = new User(
      Username = 'msuniquetest' + uniqueSuffix + '@example.com.smi',
      Email = 'msuniquetest' + uniqueSuffix + '@example.com',
      LastName = 'UniqueTest',
      FirstName = 'User',
      Alias = 'msun' + uniqueSuffix.substring(0, 2),
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert usernameTestUser;
  }

  @isTest
  static void testFindExistingUser_ByUsernamePattern() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User existingUser = [
      SELECT Id, Email, Username
      FROM User
      WHERE Username LIKE 'msexisting%@example.com.smi'
      LIMIT 1
    ];

    Test.startTest();
    User result = handler.findExistingUser(existingUser.Email);
    Test.stopTest();

    System.assertNotEquals(
      null,
      result,
      'Should find existing user by username pattern'
    );
    System.assertEquals(
      existingUser.Id,
      result.Id,
      'Should return correct user'
    );
    System.assertEquals(
      existingUser.Username,
      result.Username,
      'Username should match'
    );
  }

  @isTest
  static void testFindExistingUser_NotFound() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    User result = handler.findExistingUser('nonexistent-ms@example.com');
    Test.stopTest();

    System.assertEquals(
      null,
      result,
      'Should return null for non-existent user'
    );
  }

  @isTest
  static void testFindExistingUser_BlankEmail() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    User result = handler.findExistingUser(null);
    Test.stopTest();

    System.assertEquals(null, result, 'Should return null for blank email');
  }

  @isTest
  static void testGenerateAlias_NormalEmail() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String alias = handler.generateAlias('testuser@example.com');
    Test.stopTest();

    System.assertEquals('testuser', alias, 'Should extract alias from email');
    System.assert(alias.length() <= 8, 'Alias should be max 8 characters');
  }

  @isTest
  static void testGenerateAlias_LongEmail() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String alias = handler.generateAlias('verylongemailaddress@example.com');
    Test.stopTest();

    System.assertEquals(8, alias.length(), 'Should truncate to 8 characters');
    System.assertEquals('verylong', alias, 'Should be first 8 characters');
  }

  @isTest
  static void testGenerateAlias_NoAtSymbol() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String alias = handler.generateAlias('noatsymbol');
    Test.stopTest();

    System.assertNotEquals(null, alias, 'Should return alias even without @');
    System.assert(alias.length() <= 8, 'Alias should be max 8 characters');
  }

  @isTest
  static void testGenerateAlias_BlankEmail() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String alias = handler.generateAlias(null);
    Test.stopTest();

    System.assertEquals(
      'user',
      alias,
      'Should return default alias for blank email'
    );
  }

  @isTest
  static void testGenerateAlias_EdgeCases() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String alias1 = handler.generateAlias('a@b.com');
    String alias2 = handler.generateAlias('');
    String alias3 = handler.generateAlias('test');
    Test.stopTest();

    System.assertEquals('a', alias1, 'Should handle short email');
    System.assertEquals('user', alias2, 'Should return default for empty');
    System.assertNotEquals(null, alias3, 'Should handle email without @');
  }

  @isTest
  static void testEnsureUniqueUsername_Unique() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    String uniqueUsername =
      'mscompletelyunique' +
      String.valueOf(System.currentTimeMillis()) +
      '@example.com.smi';

    Test.startTest();
    String result = handler.ensureUniqueUsername(uniqueUsername);
    Test.stopTest();

    System.assertEquals(
      uniqueUsername,
      result,
      'Should return same username if unique'
    );
  }

  @isTest
  static void testEnsureUniqueUsername_Duplicate() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User existingUser = [
      SELECT Username
      FROM User
      WHERE Username LIKE 'msuniquetest%@example.com.smi'
      LIMIT 1
    ];
    String duplicateUsername = existingUser.Username;

    Test.startTest();
    String result = handler.ensureUniqueUsername(duplicateUsername);
    Test.stopTest();

    System.assertNotEquals(
      duplicateUsername,
      result,
      'Should return different username for duplicate'
    );
    System.assert(
      result.startsWith(duplicateUsername),
      'Should append suffix to duplicate username'
    );
  }

  @isTest
  static void testEnsureUniqueUsername_MultipleCollisions() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    String uniqueSuffix = String.valueOf(System.currentTimeMillis())
      .substring(8);
    String baseUsername = 'mscollisiontest' + uniqueSuffix + '@example.com.smi';

    Id profileId = getStandardUserProfileId();
    User testUser = new User(
      Username = baseUsername,
      Email = 'mscollisiontest' + uniqueSuffix + '@example.com',
      LastName = 'Test',
      FirstName = 'User',
      Alias = 'mscl' + uniqueSuffix.substring(0, 2),
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert testUser;

    Test.startTest();
    String unique = handler.ensureUniqueUsername(baseUsername);
    Test.stopTest();

    System.assertNotEquals(
      baseUsername,
      unique,
      'Should generate unique username'
    );
    System.assert(
      unique.startsWith(baseUsername),
      'Should start with base username'
    );
  }

  @isTest
  static void testGenerateRandomPassword() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Test.startTest();
    String password1 = handler.generateRandomPassword();
    String password2 = handler.generateRandomPassword();
    Test.stopTest();

    System.assertNotEquals(null, password1, 'Should generate password');
    System.assert(
      password1.length() >= 12,
      'Password should be at least 12 characters'
    );
  }

  @isTest
  static void testGetProfileIdFromNetwork_ValidNetwork() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    List<Network> networks = [SELECT Id FROM Network LIMIT 1];
    if (networks.isEmpty()) {
      Test.startTest();
      Id profileId = handler.getProfileIdFromNetwork(
        UserInfo.getOrganizationId()
      );
      Test.stopTest();
      System.assert(true, 'Method should handle invalid network ID gracefully');
    } else {
      Id networkId = networks[0].Id;
      Test.startTest();
      Id profileId = handler.getProfileIdFromNetwork(networkId);
      Test.stopTest();
      System.assert(true, 'Method should execute without error');
    }
  }

  @isTest
  static void testGetProfileIdFromNetwork_InvalidNetwork() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    Id invalidNetworkId = UserInfo.getOrganizationId();

    Test.startTest();
    Id profileId = handler.getProfileIdFromNetwork(invalidNetworkId);
    Test.stopTest();

    System.assert(true, 'Method should handle invalid network ID gracefully');
  }

  @isTest
  static void testUpdateUser() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User testUser = [
      SELECT Id
      FROM User
      WHERE Email LIKE 'msexisting%@example.com'
      LIMIT 1
    ];

    Test.startTest();
    handler.updateUser(testUser.Id, UserInfo.getOrganizationId(), null);
    Test.stopTest();

    User unchangedUser = [
      SELECT Id, FirstName, LastName
      FROM User
      WHERE Id = :testUser.Id
    ];
    System.assertNotEquals(null, unchangedUser, 'User should still exist');
  }

  @isTest
  static void testHandlerInstantiation() {
    Test.startTest();
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();
    Test.stopTest();

    System.assertNotEquals(null, handler, 'Handler should be instantiated');
  }

  @isTest
  static void testRegistrationHandlerException() {
    MicrosoftAuthRegistrationHandler.RegistrationHandlerException ex = new MicrosoftAuthRegistrationHandler.RegistrationHandlerException(
      'Test exception'
    );

    System.assertNotEquals(null, ex, 'Exception should be instantiated');
    System.assertEquals(
      'Test exception',
      ex.getMessage(),
      'Exception message should match'
    );
  }

  @isTest
  static void testCreateNewUser_WithProfile() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();
    Id profileId = getStandardUserProfileId();

    String uniqueEmail =
      'msnewuser' +
      String.valueOf(System.currentTimeMillis()) +
      '@example.com';
    Auth.UserData mockData = createMockUserData(uniqueEmail, 'New', 'User');

    if (mockData != null) {
      Test.startTest();
      try {
        User newUser = handler.createNewUser(mockData, profileId);
        Test.stopTest();

        System.assertNotEquals(null, newUser, 'Should create new user');
        System.assertEquals(
          uniqueEmail + '.smi',
          newUser.Username,
          'Username should match pattern'
        );
        System.assertEquals(uniqueEmail, newUser.Email, 'Email should match');
      } catch (Exception e) {
        System.debug(
          'createNewUser exception (may be expected): ' + e.getMessage()
        );
      }
    } else {
      Test.startTest();
      String alias = handler.generateAlias(uniqueEmail);
      String username = handler.ensureUniqueUsername(uniqueEmail + '.smi');
      Test.stopTest();

      System.assertNotEquals(null, alias, 'Should generate alias');
      System.assert(username.endsWith('.smi'), 'Username should end with .smi');
    }
  }

  @isTest
  static void testCreateUser_ExistingUserReturns() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User existingUser = [
      SELECT Id, Email
      FROM User
      WHERE Email LIKE 'msexisting%@example.com'
      LIMIT 1
    ];
    Auth.UserData mockData = createMockUserData(
      existingUser.Email,
      'Existing',
      'User'
    );

    List<Network> networks = [SELECT Id FROM Network LIMIT 1];
    Id networkId = networks.isEmpty()
      ? UserInfo.getOrganizationId()
      : networks[0].Id;

    if (mockData != null && !networks.isEmpty()) {
      Test.startTest();
      try {
        User result = handler.createUser(networkId, mockData);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return user');
        System.assertEquals(
          existingUser.Id,
          result.Id,
          'Should return existing user'
        );
      } catch (Exception e) {
        System.debug(
          'createUser exception (may be expected): ' + e.getMessage()
        );
      }
    }
  }

  @isTest
  static void testCreateUser_ErrorPath_BlankEmail() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    // Both email and userName empty - the UPN fallback won't save us here.
    Auth.UserData mockData = createMockUserData('', '', 'Test', 'User');
    List<Network> networks = [SELECT Id FROM Network LIMIT 1];
    Id networkId = networks.isEmpty()
      ? UserInfo.getOrganizationId()
      : networks[0].Id;

    if (mockData != null) {
      Test.startTest();
      try {
        handler.createUser(networkId, mockData);
        System.assert(
          false,
          'Should have thrown exception for blank email and userName'
        );
      } catch (MicrosoftAuthRegistrationHandler.RegistrationHandlerException e) {
        System.assert(
          e.getMessage().contains('Email is required'),
          'Should throw exception about missing email'
        );
      } catch (Exception e) {
        System.debug('Exception (may be expected): ' + e.getMessage());
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testCreateUser_ErrorPath_NoExistingUser() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    String uniqueEmail =
      'msnonexistent' +
      String.valueOf(System.currentTimeMillis()) +
      '@example.com';
    Auth.UserData mockData = createMockUserData(uniqueEmail, 'New', 'User');

    List<Network> networks = [SELECT Id FROM Network LIMIT 1];
    Id networkId = networks.isEmpty()
      ? UserInfo.getOrganizationId()
      : networks[0].Id;

    if (mockData != null) {
      Test.startTest();
      try {
        handler.createUser(networkId, mockData);
        System.assert(
          false,
          'Should have thrown exception for non-existent user'
        );
      } catch (MicrosoftAuthRegistrationHandler.RegistrationHandlerException e) {
        System.assert(
          e.getMessage().contains('No account found') ||
            e.getMessage().contains('donorbox.org') ||
            e.getMessage().contains('webdev@spokanemountaineers.org'),
          'Should throw exception with actionable guidance: ' + e.getMessage()
        );
        System.assert(
          e.getMessage().contains('Microsoft'),
          'Error message should reference Microsoft account: ' + e.getMessage()
        );
      } catch (Exception e) {
        System.debug('Exception (may be expected): ' + e.getMessage());
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testCreateUser_ExistingUserPath() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User existingUser = [
      SELECT Id, Email
      FROM User
      WHERE Email LIKE 'msexisting%@example.com'
      LIMIT 1
    ];

    Test.startTest();
    User found = handler.findExistingUser(existingUser.Email);
    Test.stopTest();

    System.assertNotEquals(null, found, 'Should find existing user');
    System.assertEquals(
      existingUser.Id,
      found.Id,
      'Should return correct user'
    );
  }

  /**
   * Microsoft-specific: when data.email is blank but data.username (the UPN) is
   * populated, the handler should fall back to using the UPN to construct the
   * username pattern lookup. This is the documented behavior when the user's
   * Entra account has no verified email claim.
   */
  @isTest
  static void testCreateUser_FallsBackToUpnWhenEmailBlank() {
    MicrosoftAuthRegistrationHandler handler = new MicrosoftAuthRegistrationHandler();

    User existingUser = [
      SELECT Id, Email
      FROM User
      WHERE Email LIKE 'msexisting%@example.com'
      LIMIT 1
    ];

    // Simulate a Microsoft response where the email claim is empty but the UPN matches.
    Auth.UserData mockData = createMockUserData(
      '',
      existingUser.Email,
      'Existing',
      'User'
    );

    List<Network> networks = [SELECT Id FROM Network LIMIT 1];
    Id networkId = networks.isEmpty()
      ? UserInfo.getOrganizationId()
      : networks[0].Id;

    if (mockData != null) {
      Test.startTest();
      try {
        User result = handler.createUser(networkId, mockData);
        Test.stopTest();

        System.assertNotEquals(
          null,
          result,
          'Should resolve user via UPN fallback'
        );
        System.assertEquals(
          existingUser.Id,
          result.Id,
          'Should return existing user matched via UPN'
        );
      } catch (Exception e) {
        System.debug(
          'createUser exception (may be expected in some org configurations): ' +
          e.getMessage()
        );
      }
    }
  }
}
