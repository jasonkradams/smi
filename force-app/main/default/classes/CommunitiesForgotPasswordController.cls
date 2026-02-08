/**
 * Controller for custom Community forgot password page.
 * Handles password reset email functionality for community users.
 *
 * @author Spokane Mountaineers
 * @date 2026-02-05
 */
public without sharing class CommunitiesForgotPasswordController {
  // Form inputs
  public String username { get; set; }

  // Page state
  public Boolean hasError { get; set; }
  public Boolean isSuccess { get; set; }

  /**
   * Constructor - Initialize page state
   */
  public CommunitiesForgotPasswordController() {
    this.hasError = false;
    this.isSuccess = false;
  }

  /**
   * Handle forgot password form submission
   * Sends password reset email to the provided username/email
   *
   * @return PageReference null to stay on same page and show messages
   */
  public PageReference forgotPassword() {
    try {
      // Validate input
      if (String.isBlank(username)) {
        ApexPages.addMessage(
          new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Please enter your email address.'
          )
        );
        this.hasError = true;
        this.isSuccess = false;
        return null;
      }

      // Normalize username: append .smi suffix if not present (for consistency with login)
      String normalizedUsername = normalizeUsername(username.trim());

      // Call Site.forgotPassword which sends the reset email
      // Returns true if successful, false otherwise
      Boolean result = Site.forgotPassword(normalizedUsername);

      // Always show success message for security reasons
      // (don't reveal if account exists or not)
      this.isSuccess = true;
      this.hasError = false;

      return null;
    } catch (Exception e) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'An error occurred. Please try again.'
        )
      );
      this.hasError = true;
      this.isSuccess = false;
      return null;
    }
  }

  /**
   * Normalize username by appending .smi suffix if not present
   * Allows users to reset password with just their email address
   *
   * @param rawUsername The username entered by user
   * @return Normalized username with .smi suffix
   */
  @TestVisible
  private String normalizeUsername(String rawUsername) {
    if (String.isBlank(rawUsername)) {
      return rawUsername;
    }

    // Append .smi suffix if not already present (case insensitive)
    if (!rawUsername.endsWithIgnoreCase('.smi')) {
      return rawUsername + '.smi';
    }

    return rawUsername;
  }

  /**
   * Get the login URL for the community
   * Returns the direct path to the configured CommunitiesLogin Visualforce page
   *
   * @return URL to login page
   */
  public String getLoginUrl() {
    String communityUrl = Site.getBaseUrl();
    if (String.isNotBlank(communityUrl)) {
      return communityUrl + '/CommunitiesLogin';
    }
    return '/CommunitiesLogin';
  }
}
