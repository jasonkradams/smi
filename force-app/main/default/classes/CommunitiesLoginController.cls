/**
 * Controller for custom Community login page with username normalization.
 * Automatically appends .smi suffix to usernames to support email-based login.
 *
 * @author Spokane Mountaineers
 * @date 2026-02-05
 */
public without sharing class CommunitiesLoginController {
  // Form inputs
  public String username { get; set; }
  public String password { get; set; }

  // Page state
  public String startUrl { get; set; }
  public Boolean hasError { get; set; }

  /**
   * Constructor - Initialize page state and capture startURL parameter
   */
  public CommunitiesLoginController() {
    this.hasError = false;
    this.startUrl = System.currentPageReference()
      .getParameters()
      .get('startURL');

    // Default to home if no startURL provided
    if (String.isBlank(this.startUrl)) {
      this.startUrl = '/s/';
    }
  }

  /**
   * Handle login form submission
   * Normalizes username by appending .smi suffix if not present and authenticates user
   *
   * @return PageReference to redirect after successful login, null on error
   */
  public PageReference login() {
    try {
      // Validate inputs
      if (String.isBlank(username) || String.isBlank(password)) {
        ApexPages.addMessage(
          new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Please enter both username and password.'
          )
        );
        this.hasError = true;
        return null;
      }

      // Normalize username: append .smi suffix if not present
      String normalizedUsername = normalizeUsername(username.trim());

      // Attempt authentication with normalized username
      PageReference result = Site.login(normalizedUsername, password, startUrl);

      // If login successful, Site.login returns a PageReference
      // If failed, it returns null
      if (result != null) {
        return result;
      } else {
        ApexPages.addMessage(
          new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Invalid username or password. Please try again.'
          )
        );
        this.hasError = true;
        return null;
      }
    } catch (Exception e) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'An error occurred during login. Please try again.'
        )
      );
      this.hasError = true;
      return null;
    }
  }

  /**
   * Normalize username by appending .smi suffix if not present
   * Allows users to login with just their email address
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
   * Get the forgot password URL for the community
   * Returns the direct path to the CommunitiesForgotPassword Visualforce page
   *
   * Note: We use the direct Visualforce page path instead of the generic /ForgotPassword
   * route due to a known Salesforce platform limitation where Experience Cloud's Login &
   * Registration settings don't reliably override authentication routes for Visualforce pages.
   *
   * @return URL to forgot password page
   */
  public String getForgotPasswordUrl() {
    String communityUrl = Site.getBaseUrl();
    if (String.isNotBlank(communityUrl)) {
      return communityUrl + '/CommunitiesForgotPassword';
    }
    return '/CommunitiesForgotPassword';
  }

  /**
   * Get the Google OAuth login URL
   * This is configured in Setup > Auth Providers > Google
   *
   * @return URL to initiate Google OAuth flow
   */
  public String getGoogleLoginUrl() {
    // Get the current site's base URL
    String communityUrl = Site.getBaseUrl();

    // Construct Google auth URL
    // Format: /services/auth/sso/Google?startURL={startUrl}
    String googleUrl = communityUrl + '/services/auth/sso/Google';

    if (String.isNotBlank(startUrl)) {
      googleUrl += '?startURL=' + EncodingUtil.urlEncode(startUrl, 'UTF-8');
    }

    return googleUrl;
  }

  /**
   * Get the admin/internal Salesforce login URL
   * This allows system admins to access the internal org from the community login page
   *
   * @return URL to internal Salesforce login
   */
  public String getAdminLoginUrl() {
    // Get the org's base URL (e.g., https://mydomain.my.salesforce.com)
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();

    // Return the standard login page
    return orgUrl;
  }
}
