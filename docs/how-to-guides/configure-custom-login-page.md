# Configure Custom Login Page for Experience Cloud

This guide walks through deploying and configuring the custom login page with modern UI and `.smi` username normalization.

## Overview

The custom login page provides:

- Modern, responsive UI design
- Loading spinner during authentication
- Password visibility toggle
- Alpine.js-powered interactivity
- Automatic `.smi` suffix stripping for backward compatibility

## Prerequisites

- Salesforce CLI installed
- Access to the target org (Staging or Production)
- Admin permissions to configure Experience Cloud site

## Component Overview

### Files Created

1. **CommunitiesLoginController.cls** - Apex controller handling login logic
2. **CommunitiesLoginControllerTest.cls** - Test class with 100% coverage
3. **CommunitiesLogin.page** - Visualforce page with modern UI

### Key Features

#### Username Normalization

The controller automatically strips the `.smi` suffix from usernames:

- User enters: `user@example.com.smi`
- System processes: `user@example.com`
- Supports legacy user habits after migration

#### Modern UI Components

- **Loading State**: Spinner appears during login, button disabled
- **Password Toggle**: Eye icon to show/hide password
- **Google OAuth**: Styled button for Google sign-in
- **Responsive**: Works on mobile, tablet, and desktop

## Deployment Steps

### 1. Deploy to Sandbox (Staging)

First, always test in staging before production:

```bash
# Make sure you're on the feature branch
git checkout feature/custom-login-page

# Deploy to staging sandbox
sf project deploy start \
  --source-dir force-app/main/default/classes/CommunitiesLoginController.cls \
  --source-dir force-app/main/default/classes/CommunitiesLoginControllerTest.cls \
  --source-dir force-app/main/default/pages/CommunitiesLogin.page \
  --target-org staging \
  --test-level RunLocalTests

# Or deploy all changes at once
sf project deploy start \
  --source-dir force-app/main/default \
  --target-org staging \
  --test-level RunLocalTests
```

### 2. Run Tests in Staging

Verify all tests pass:

```bash
# Run specific test class
sf apex run test \
  --class-names CommunitiesLoginControllerTest \
  --target-org staging \
  --result-format human \
  --code-coverage

# Verify 75%+ org-wide coverage
sf apex get test \
  --code-coverage \
  --result-format human \
  --target-org staging
```

### 3. Configure Staging Experience Cloud Site

#### Step-by-Step Configuration

1. **Navigate to Digital Experiences**
    - Setup → Digital Experiences → All Sites
    - Click **Builder** next to your site
    - Or click **Administration**

2. **Access Login & Registration Settings**
    - In Builder: Click ⚙️ (Settings) → **Login & Registration**
    - Or in Administration: Click **Login & Registration**

3. **Configure Login Page**
    - Under **Login Page**, select **Change Login Page**
    - Choose **Visualforce Page**
    - Select `CommunitiesLogin` from dropdown
    - Click **OK**

4. **Configure Google OAuth (if using)**
    - Verify Auth Provider is configured: Setup → Auth. Providers
    - Ensure Google provider is active and configured

5. **Save and Publish**
    - Click **Save** in the Settings modal
    - Click **Publish** in the Builder to make changes live

#### Alternative: Configure via Setup

If you prefer Setup over Builder:

1. Setup → Digital Experiences → All Sites
2. Click dropdown next to site → **Administration**
3. Under **Settings**, click **Login & Registration**
4. Follow steps 3-5 above

### 4. Test in Staging

#### Test Scenarios

**Test with .smi suffix:**

```
Username: testuser@example.com.smi
Password: YourPassword123
Expected: Login succeeds, .smi stripped automatically
```

**Test without .smi suffix:**

```
Username: testuser@example.com
Password: YourPassword123
Expected: Login succeeds as normal
```

**Test Google OAuth:**

1. Click "Continue with Google" button
2. Authenticate with Google
3. Verify redirect to startURL

**Test Password Toggle:**

1. Enter password
2. Click eye icon
3. Verify password becomes visible
4. Click eye icon again
5. Verify password hidden

**Test Loading State:**

1. Enter credentials
2. Click "Sign In"
3. Verify spinner appears and button shows "Signing in..."
4. Verify button is disabled during processing

**Test Mobile Responsiveness:**

1. Open site on mobile device or use browser dev tools
2. Verify layout adapts to smaller screen
3. Test all features work on mobile

### 5. Validation Checklist

Before deploying to production, verify:

- [ ] All unit tests pass (75%+ coverage)
- [ ] Login works with `.smi` suffix
- [ ] Login works without `.smi` suffix
- [ ] Google OAuth login works
- [ ] Forgot password link works
- [ ] Sign up link works
- [ ] Renew link works
- [ ] Password toggle works
- [ ] Loading spinner appears
- [ ] Error messages display properly
- [ ] Mobile responsive design works
- [ ] No console errors in browser

## Deploy to Production

Once staging validation is complete:

```bash
# Deploy to production
sf project deploy start \
  --source-dir force-app/main/default/classes/CommunitiesLoginController.cls \
  --source-dir force-app/main/default/classes/CommunitiesLoginControllerTest.cls \
  --source-dir force-app/main/default/pages/CommunitiesLogin.page \
  --target-org production \
  --test-level RunLocalTests

# Run tests
sf apex run test \
  --class-names CommunitiesLoginControllerTest \
  --target-org production \
  --result-format human \
  --code-coverage
```

Follow the same configuration steps as staging (Section 3).

## Customization Options

### Change Colors

Edit the CSS in `CommunitiesLogin.page`:

```css
/* Change gradient background */
background: linear-gradient(135deg, #YOUR_COLOR1 0%, #YOUR_COLOR2 100%);

/* Change button colors */
.btn-primary {
    background: linear-gradient(135deg, #YOUR_COLOR1 0%, #YOUR_COLOR2 100%);
}
```

### Change Logo

Replace the SVG logo in the page with your image:

```html
<!-- Replace the SVG with an image tag -->
<img src="{!$Resource.YourLogoResource}" alt="Your Organization" class="logo" />
```

### Add Custom Labels

Custom labels have been created for commonly changing URLs and email addresses.

**Available Custom Labels**

| Label Name                | Value                                                    | Description                                |
| ------------------------- | -------------------------------------------------------- | ------------------------------------------ |
| `Community_Join_URL`      | `https://donorbox.org/spokane-mountaineers-membership-2` | URL for new member registration/join       |
| `Community_Renew_URL`     | `https://donorbox.org/spokane-mountaineers-membership`   | URL for membership renewal                 |
| `Community_Support_Email` | `membership@spokanemountaineers.org`                     | Support email address for member questions |

**To modify these values:**

1. Setup → Custom Labels
2. Find the label by name
3. Click **Edit**
4. Update the **Value** field
5. Click **Save**

Changes take effect immediately without code deployment.

### Modify Session Duration

Salesforce session duration is controlled by session settings:

1. Setup → Session Settings
2. Configure **Session Timeout** value
3. This controls how long sessions persist

## Troubleshooting

### Issue: Login fails with "Invalid username or password"

**Possible Causes:**

1. Username normalization not working
2. User doesn't exist in database
3. Incorrect password

**Resolution:**

1. Check debug logs in Developer Console
2. Verify `normalizeUsername()` is stripping `.smi`
3. Query User object: `SELECT Id, Username FROM User WHERE Email = 'user@example.com'`

### Issue: Google OAuth button doesn't work

**Possible Causes:**

1. Auth Provider not configured
2. Google OAuth credentials invalid
3. Callback URL mismatch

**Resolution:**

1. Setup → Auth. Providers → Google
2. Verify Client ID and Client Secret
3. Check Callback URL matches Google Console
4. Test URL format: `/services/auth/sso/Google`

### Issue: Page styles not loading

**Possible Causes:**

1. CDN blocked (Alpine.js)
2. CSS not rendering
3. Browser caching

**Resolution:**

1. Check browser console for errors
2. Verify network can reach CDN: `https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js`
3. Clear browser cache
4. Test in incognito mode

### Issue: Password toggle not working

**Possible Causes:**

1. JavaScript error
2. Input type binding issue

**Resolution:**

1. Check browser console for errors
2. Verify password field ID is correct

### Issue: Forgot Password routing with Visualforce pages

**Known Platform Limitation:**

Experience Cloud's Login & Registration settings don't reliably override authentication routes (`/ForgotPassword`) when using Visualforce pages. This is a known Salesforce platform limitation where hardcoded authentication servlet routes don't respect Experience Builder configuration for Visualforce pages.

**Current Implementation:**

The `CommunitiesLoginController.getForgotPasswordUrl()` method uses the direct Visualforce page path (`/CommunitiesForgotPassword`) instead of the generic route (`/ForgotPassword`). This ensures users always see the custom branded forgot password page.

**Alternative Solutions (if needed in the future):**

- Convert to Lightning Web Component (LWC) - Experience Builder routing works properly with Lightning components
- Use the direct URL pattern as the canonical approach for authentication flows

## Testing Commands

### Run All Tests

```bash
# Run all Apex tests in org
sf apex run test \
  --test-level RunLocalTests \
  --target-org staging \
  --result-format human \
  --code-coverage \
  --wait 30
```

### Run Specific Test Class

```bash
sf apex run test \
  --class-names CommunitiesLoginControllerTest \
  --target-org staging \
  --result-format human \
  --code-coverage
```

### Check Code Coverage

```bash
sf apex get test \
  --code-coverage \
  --target-org staging \
  --result-format human
```

### View Debug Logs

```bash
# Get recent logs
sf apex list log --target-org staging

# Download specific log
sf apex get log --log-id YOUR_LOG_ID --target-org staging
```

## Rollback Procedure

If issues occur in production:

1. **Revert to Standard Login Page**
    - Setup → Digital Experiences → All Sites
    - Click **Administration** → **Login & Registration**
    - Change **Login Page** back to "Default"
    - Click **Save** and **Publish**

2. **Users Can Still Login**
    - Standard Salesforce login page will be used
    - `.smi` normalization won't work (users must use exact username)

3. **Fix Issues and Redeploy**
    - Address the issue in staging
    - Test thoroughly
    - Redeploy to production when ready

## Support

For questions or issues:

- Email: info@spokanemountaineers.org
- GitHub: Create an issue in the repository
- Slack: #tech-support channel

## Related Documentation

- [Username Migration Plan](../proposals/remove-smi-from-usernames.md)
- [Google OAuth Setup](../articles/enable-google-login.md)
- [Experience Cloud Configuration](./setup-staging-sandbox.md)
