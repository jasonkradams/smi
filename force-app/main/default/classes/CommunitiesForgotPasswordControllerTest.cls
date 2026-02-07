/**
 * Test class for CommunitiesForgotPasswordController
 * Provides code coverage and validates forgot password functionality
 *
 * @author Spokane Mountaineers
 * @date 2026-02-05
 */
@isTest
private class CommunitiesForgotPasswordControllerTest {
  /**
   * Test controller initialization
   */
  @isTest
  static void testControllerInitialization() {
    // Given: A new controller instance
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();

    // Then: Initial state should be set correctly
    System.assertEquals(
      false,
      controller.hasError,
      'Should not have error on initialization'
    );
    System.assertEquals(
      false,
      controller.isSuccess,
      'Should not show success on initialization'
    );
    System.assertEquals(
      null,
      controller.username,
      'Username should be null on initialization'
    );
  }

  /**
   * Test forgot password with empty username
   */
  @isTest
  static void testForgotPasswordWithEmptyUsername() {
    // Given: A controller with no username
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();
    controller.username = '';

    // When: Forgot password is called
    PageReference result = controller.forgotPassword();

    // Then: Should show error and not success
    System.assertEquals(null, result, 'Should return null to stay on page');
    System.assertEquals(
      true,
      controller.hasError,
      'Should have error for empty username'
    );
    System.assertEquals(
      false,
      controller.isSuccess,
      'Should not show success for empty username'
    );
    System.assert(
      ApexPages.hasMessages(ApexPages.Severity.ERROR),
      'Should have error message'
    );
  }

  /**
   * Test forgot password with valid username
   */
  @isTest
  static void testForgotPasswordWithValidUsername() {
    // Given: A controller with valid username
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();
    controller.username = 'test@example.com';

    // When: Forgot password is called
    Test.startTest();
    PageReference result = controller.forgotPassword();
    Test.stopTest();

    // Then: Should show success (always for security)
    System.assertEquals(null, result, 'Should return null to stay on page');
    System.assertEquals(
      true,
      controller.isSuccess,
      'Should show success message'
    );
    System.assertEquals(
      false,
      controller.hasError,
      'Should not have error for valid request'
    );
  }

  /**
   * Test forgot password with .smi suffix in username
   */
  @isTest
  static void testForgotPasswordWithSmiSuffix() {
    // Given: A controller with username containing .smi suffix
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();
    controller.username = 'test@example.com.smi';

    // When: Forgot password is called
    Test.startTest();
    PageReference result = controller.forgotPassword();
    Test.stopTest();

    // Then: Should show success (username normalized internally)
    System.assertEquals(null, result, 'Should return null to stay on page');
    System.assertEquals(
      true,
      controller.isSuccess,
      'Should show success with normalized username'
    );
    System.assertEquals(false, controller.hasError, 'Should not have error');
  }

  /**
   * Test username normalization (private method via forgot password)
   */
  @isTest
  static void testUsernameNormalization() {
    // Given: Controller instances with various usernames
    CommunitiesForgotPasswordController controller1 = new CommunitiesForgotPasswordController();
    CommunitiesForgotPasswordController controller2 = new CommunitiesForgotPasswordController();
    CommunitiesForgotPasswordController controller3 = new CommunitiesForgotPasswordController();

    // When: Processing usernames with different suffixes
    Test.startTest();
    controller1.username = 'test@example.com.smi';
    controller1.forgotPassword();

    controller2.username = 'test@example.COM.SMI'; // Case variation
    controller2.forgotPassword();

    controller3.username = 'test@example.com'; // No suffix
    controller3.forgotPassword();
    Test.stopTest();

    // Then: All should succeed (normalization happens internally)
    System.assertEquals(
      true,
      controller1.isSuccess,
      'Should succeed with lowercase .smi'
    );
    System.assertEquals(
      true,
      controller2.isSuccess,
      'Should succeed with uppercase .SMI'
    );
    System.assertEquals(
      true,
      controller3.isSuccess,
      'Should succeed without suffix'
    );
  }

  /**
   * Test getLoginUrl method
   */
  @isTest
  static void testGetLoginUrl() {
    // Given: A controller instance
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();

    // When: Getting login URL
    String loginUrl = controller.getLoginUrl();

    // Then: Should return valid login URL
    System.assertNotEquals(null, loginUrl, 'Login URL should not be null');
    System.assert(
      loginUrl.contains('CommunitiesLogin'),
      'Login URL should contain "CommunitiesLogin"'
    );
  }

  /**
   * Test forgot password with whitespace in username
   */
  @isTest
  static void testForgotPasswordWithWhitespace() {
    // Given: A controller with username containing whitespace
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();
    controller.username = '  test@example.com  ';

    // When: Forgot password is called
    Test.startTest();
    PageReference result = controller.forgotPassword();
    Test.stopTest();

    // Then: Should show success (whitespace trimmed internally)
    System.assertEquals(null, result, 'Should return null to stay on page');
    System.assertEquals(
      true,
      controller.isSuccess,
      'Should show success with trimmed username'
    );
    System.assertEquals(false, controller.hasError, 'Should not have error');
  }

  /**
   * Test forgot password with null username
   */
  @isTest
  static void testForgotPasswordWithNullUsername() {
    // Given: A controller with null username
    CommunitiesForgotPasswordController controller = new CommunitiesForgotPasswordController();
    controller.username = null;

    // When: Forgot password is called
    PageReference result = controller.forgotPassword();

    // Then: Should show error
    System.assertEquals(null, result, 'Should return null to stay on page');
    System.assertEquals(
      true,
      controller.hasError,
      'Should have error for null username'
    );
    System.assertEquals(
      false,
      controller.isSuccess,
      'Should not show success for null username'
    );
  }
}
