# Custom Login Page Implementation Details

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Implementation Timeline](#implementation-timeline)
- [Component Details](#component-details)
- [Testing Strategy](#testing-strategy)
- [Configuration Management](#configuration-management)
- [Lessons Learned](#lessons-learned)

## Overview

This document provides detailed technical information about the custom login page implementation for the Spokane Mountaineers Experience Cloud site. The primary goal of this implementation is to make the `.smi` username suffix transparent to members while maintaining Salesforce's global username uniqueness requirement.

### Background: The `.smi` Username Requirement

Salesforce requires usernames to be globally unique across all Salesforce organizations worldwide. This is a current platform constraint, not a historical one. To ensure our members had unique usernames in this global namespace, we append `.smi` to every member's email address (e.g., `jane.smith@gmail.com` becomes `jane.smith@gmail.com.smi`).

This approach solves the uniqueness problem but creates member confusion—members don't understand why they need to add `.smi` when logging in.

### The Challenge

We cannot migrate away from `.smi` usernames because:

1. **Global Uniqueness Constraint**: Salesforce still requires globally unique usernames
2. **Member Email Conflicts**: Many members likely have their email addresses registered as usernames in other Salesforce organizations (work orgs, other communities, etc.)
3. **Migration Would Fail**: Attempting to change `jane@gmail.com.smi` to `jane@gmail.com` would fail if that username exists anywhere in Salesforce

### The Solution: Make `.smi` Transparent

Rather than trying to eliminate `.smi` (which isn't viable), we make it transparent to members. The standard Salesforce Experience Cloud login page doesn't allow custom scripting to transform input values, so we built custom authentication pages that automatically append `.smi` if members don't include it.

### Goals

1. Allow members to enter just their email address (without `.smi`)
2. Automatically append `.smi` before authentication if not present
3. Support members who still type `.smi` out of habit (backward compatible)
4. Work for both login and password reset flows
5. Provide a modern, branded experience
6. Ensure comprehensive test coverage

## Architecture

### Component Overview

```
Experience Cloud Authentication Flow
│
├── CommunitiesLogin (Visualforce Page)
│   ├── CommunitiesLoginController.cls
│   └── CommunitiesLoginControllerTest.cls
│
├── CommunitiesForgotPassword (Visualforce Page)
│   ├── CommunitiesForgotPasswordController.cls
│   └── CommunitiesForgotPasswordControllerTest.cls
│
└── Configuration
    ├── Custom Labels (Community_Join_URL, etc.)
    └── Guest User Profile (Page Access)
```

### Key Design Decisions

**Visualforce Over Lightning Web Components**: We chose Visualforce for the authentication pages because:

- Experience Cloud's authentication servlet routes work more reliably with Visualforce
- Simpler integration with `Site.login()` and `Site.forgotPassword()` methods
- Mature platform with well-documented authentication patterns
- Custom scripting not possible with standard Experience Cloud login pages

**Username Normalization**: Both login and forgot password flows automatically append the `.smi` suffix if members don't include it. This is the core functionality enabling email-based login:

```apex
// In CommunitiesLoginController and CommunitiesForgotPasswordController
if (!username.endsWithIgnoreCase('.smi')) {
  username = username + '.smi';
}
```

This approach means members can enter just their email address, and the system will authenticate them correctly. Members who still type `.smi` out of habit aren't affected—the check ensures we don't double-append the suffix.

**Custom Labels for URLs**: Rather than hardcoding URLs in Visualforce pages, we use custom labels. This allows non-technical administrators to update URLs through the Salesforce UI without code changes.

## Implementation Timeline

This implementation was completed in six atomic commits, each building on the previous work to create a complete email-based login solution.

### Phase 1: Initial Login Page (Commits 4e86d22, 80e16a6)

**Created**: Custom login page with username normalization

**Primary Goal**: Enable automatic `.smi` appending to support email-based login

**Features**:
- Username normalization (automatically appends `.smi` suffix if not present)
- Modern, responsive design
- Alpine.js for interactivity
- Password visibility toggle
- Google OAuth integration
- Loading states during authentication

**Why This Matters**: The standard Experience Cloud login page cannot transform input values. This custom page gives us the ability to append `.smi` before authentication, allowing members to enter just their email address.

**Components**:
- `CommunitiesLogin.page` - Visualforce page with custom styling
- `CommunitiesLoginController.cls` - Controller with username normalization logic
- `CommunitiesLoginControllerTest.cls` - Test class with comprehensive coverage

### Phase 2: Custom Labels (Commit 5008e86)

**Created**: Custom labels for frequently-changed values

**Labels Added**:
- `Community_Join_URL` - New member signup form URL
- `Community_Renew_URL` - Membership renewal form URL
- `Community_Support_Email` - Support contact email

**Rationale**: While not directly related to username migration, custom labels allow administrators to update URLs and contact information through Setup → Custom Labels without requiring code changes or deployments. This reduces maintenance burden as we evolve the authentication experience.

### Phase 3: Feature Simplification (Commit 8f6aa25)

**Removed**: Unused features to focus on core username normalization functionality

**Features Removed**:
- Remember me checkbox (redundant with Salesforce session settings)
- Self-registration URL method (not used in current flow)
- Unnecessary debug logging

**Benefits**:
- Simpler codebase focused on username normalization
- Reduced maintenance burden
- Clearer code intention
- Fewer test cases to maintain

**Why This Matters**: Removing features that weren't contributing to the email-based login goal simplified the codebase and made the core functionality more obvious. This refactoring made the code easier to understand and maintain.

### Phase 4: Forgot Password Page (Commit 5b9a504)

**Created**: Custom forgot password page with username normalization

**Primary Goal**: Complete the authentication flow by supporting automatic `.smi` appending in password resets

**Features**:
- Matching visual design with login page
- Username normalization (appends `.smi` suffix if not present)
- Same background image and styling
- Responsive layout
- Loading states and error handling

**Why This Matters**: Members who forget their password need the same username normalization support. Without this custom page, a member entering just their email address on the forgot password form would fail to receive a reset email.

**Components**:
- `CommunitiesForgotPassword.page` - Visualforce page
- `CommunitiesForgotPasswordController.cls` - Controller with password reset and normalization logic
- `CommunitiesForgotPasswordControllerTest.cls` - Test class (100% coverage)

### Phase 5: Guest Profile Configuration (Commit fbc0ead)

**Created**: Guest user profile with page access permissions

**Configuration**: Added Visualforce page access to guest user profile for:
- `CommunitiesLogin`
- `CommunitiesForgotPassword`

**Why This Matters**: Unauthenticated users (those not logged in) need explicit permission to view Visualforce pages in Experience Cloud. Without this configuration, members attempting to access the custom login and forgot password pages would see an error.

### Phase 6: Documentation Updates (Commit 896773a)

**Updated**: Configuration guide to reflect current implementation

**Changes**:
- Removed documentation for removed features (remember me, self-registration)
- Added custom labels documentation
- Updated test scenarios to match actual functionality
- Simplified troubleshooting sections
- Clarified the email-based login approach (appending `.smi`, not removing it)

**Why This Matters**: Documentation that doesn't match implementation creates confusion and wastes time. This update ensures the configuration guide accurately reflects the system's current state and the email-based login goal.

## Component Details

### CommunitiesLoginController

**Purpose**: Handles login authentication and URL generation for the community

**Key Methods**:

```apex
public PageReference login()
```
Main login method that:
1. Normalizes username by appending `.smi` suffix if not present
2. Calls `Site.login()` with credentials and startURL
3. Handles errors with user-friendly messages
4. Returns null on error to stay on page, or PageReference on success

```apex
public String getForgotPasswordUrl()
```
Returns the URL to the custom forgot password page based on the current site's base URL.

```apex
public String getGoogleLoginUrl()
```
Generates the Google OAuth login URL with proper redirect handling and startURL preservation.

**Properties**:
- `username` - User-entered username
- `password` - User-entered password
- `startUrl` - URL to redirect to after successful login
- `hasError` - Boolean flag for error state

### CommunitiesForgotPasswordController

**Purpose**: Handles password reset requests with username normalization

**Key Methods**:

```apex
public PageReference forgotPassword()
```
Main password reset method that:
1. Validates username is provided
2. Normalizes username by appending `.smi` suffix if not present
3. Calls `Site.forgotPassword()` to send reset email
4. Returns user to login page with confirmation message
5. Handles errors gracefully

```apex
public String getLoginUrl()
```
Returns the URL to the custom login page for easy navigation back.

**Properties**:
- `username` - User-entered username
- `hasError` - Boolean flag for error state

### Visualforce Page Structure

Both pages share a common structure:

**Head Section**:
- Alpine.js CDN for interactivity
- Tailwind CSS CDN for styling
- Custom inline styles for branding
- Favicon reference

**Body Structure**:
```html
<body class="min-h-screen bg-cover bg-center">
  <div class="background-overlay">
    <div class="container mx-auto">
      <div class="form-container">
        <apex:form>
          <!-- Logo, heading, form fields -->
          <!-- Error messages -->
          <!-- Submit button with loading state -->
          <!-- Helper links -->
        </apex:form>
      </div>
      <div class="info-container">
        <!-- Helpful information panel -->
      </div>
    </div>
  </div>
</body>
```

**Alpine.js Data**:
- `loading` - Boolean for button/spinner state
- `showPassword` - Boolean for password visibility toggle (login only)

## Testing Strategy

### Test Coverage Goals

All controllers achieve 100% code coverage with comprehensive test scenarios:

**CommunitiesLoginControllerTest**:
- Constructor initialization
- Successful login
- Login with empty username
- Login with empty password
- Login with invalid credentials
- Forgot password URL generation
- Google login URL generation
- Google login URL with startURL parameter

**CommunitiesForgotPasswordControllerTest**:
- Constructor initialization
- Successful password reset
- Password reset with empty username
- Password reset with invalid username
- Username normalization (appends `.smi` suffix when not present)
- Login URL generation

### Test Data Strategy

Tests use:
- Standard test users where possible
- Mock page parameters for startURL testing
- `Test.startTest()` and `Test.stopTest()` for governor limit isolation
- Proper assertions for both positive and negative test cases

### Running Tests

```bash
# Run all login-related tests
sf apex run test --tests CommunitiesLoginControllerTest --tests CommunitiesForgotPasswordControllerTest --target-org production --code-coverage --result-format human

# Run individual test class
sf apex run test --tests CommunitiesLoginControllerTest --target-org production --code-coverage --result-format human
```

## Configuration Management

### Custom Labels

Custom labels enable easy configuration updates without code deployment.

**Creating a Custom Label**:

1. Setup → Custom Labels → New Custom Label
2. Fill in required fields:
   - **Name**: `Community_Join_URL`
   - **Value**: `https://donorbox.org/spokane-mountaineers-membership-2`
   - **Description**: URL for new member signup
   - **Category**: Community
   - **Protected**: No (unchecked)
3. Save

**Using in Visualforce**:

```html
<a href="{!$Label.Community_Join_URL}" class="link">
  Sign up for membership
</a>
```

**Current Custom Labels**:

| Label Name | Value | Purpose |
|------------|-------|---------|
| `Community_Join_URL` | `https://donorbox.org/spokane-mountaineers-membership-2` | New member signup form |
| `Community_Renew_URL` | `https://donorbox.org/spokane-mountaineers-membership` | Membership renewal form |
| `Community_Support_Email` | `membership@spokanemountaineers.org` | Support contact email |

### Guest User Profile

The guest user profile must have access to both Visualforce pages for unauthenticated access.

**Verifying Profile Access**:

1. Setup → Profiles → [Guest User Profile]
2. Scroll to "Enabled Apex Page Access"
3. Verify both pages are listed:
   - `CommunitiesLogin`
   - `CommunitiesForgotPassword`
4. If missing, click "Edit" and add them

### Experience Cloud Configuration

**Setting Custom Login Page**:

1. Experience Builder → Settings → Login & Registration
2. Login Page: Select "CommunitiesLogin"
3. Forgot Password Page: Select "CommunitiesForgotPassword"
4. Save and publish

## Lessons Learned

### What Worked Well

**Username Normalization Strategy**: Automatically appending the `.smi` suffix has been completely transparent to members. Members can now enter just their email address without thinking about `.smi`, while those who still type the full username out of habit aren't affected. This approach eliminates member confusion without requiring database changes.

**Verifying Platform Constraints Early**: Initial research suggested Salesforce had removed the global username uniqueness requirement. Deeper investigation revealed this constraint still exists, which fundamentally changed our approach. **Lesson: Always verify platform constraints before planning data migrations.** We pivoted from "migrate away from `.smi`" to "make `.smi` transparent," which proved to be a better solution anyway.

**Atomic, Test-Driven Implementation**: Building the solution in small, well-tested commits gave us confidence that each piece worked correctly. The comprehensive test coverage (100% for all controllers) meant we could refactor and remove features without fear of breaking authentication.

**Custom Labels**: Having URLs managed through custom labels has proven valuable for ongoing maintenance. When membership URLs change, administrators can update them immediately without waiting for a code deployment.

**Consistent Design**: Using the same background image, color scheme, and layout across both login and forgot password pages creates a cohesive user experience. Members don't experience visual discontinuity when navigating between authentication flows.

### Challenges Overcome

**Platform Constraints**: The standard Experience Cloud login page doesn't support custom scripting or input transformation. This forced us to build custom Visualforce pages, which initially seemed like extra work but ultimately gave us complete control over the authentication experience.

**Pivot from Migration to Transparency**: Discovering that Salesforce still requires globally unique usernames meant we couldn't migrate away from `.smi`. Rather than abandoning the project, we pivoted to making `.smi` transparent. This actually resulted in a simpler solution—no database migration needed, just improved UX.

**Visualforce vs Lightning Decision**: We initially considered Lightning Web Components for a more modern approach, but discovered that Visualforce integrates more smoothly with Experience Cloud authentication routes. The platform's authentication servlets (`/login`, `/ForgotPassword`) work more reliably with Visualforce pages.

**Feature Creep**: Early implementations included features like "remember me" that seemed useful but weren't actually contributing to the email-based login goal. Recognizing and removing these features simplified the codebase and made the core functionality more obvious.

**Guest Profile Permissions**: Discovering that guest users need explicit Visualforce page access wasn't immediately obvious. This caused initial access issues that were resolved by properly configuring the guest user profile with page access permissions.

### Future Considerations

**Member Communication**: Consider whether to proactively communicate to members that they can now use just their email address to log in. Some members may still be typing `.smi` unnecessarily, even though it works fine. A help article or tooltip could improve awareness.

**Analytics Integration**: Adding analytics tracking to understand:
- How many members use just email vs. full username with `.smi`
- Common login errors
- Whether members are discovering the simplified login naturally

**New Member Onboarding**: Update the member creation process documentation to clarify that usernames include `.smi` but members don't need to enter it when logging in. This ensures support staff and documentation are aligned.

**Migration to Lightning Web Components**: As Salesforce continues to evolve, we may eventually migrate to LWC-based authentication flows if platform support improves. The current Visualforce implementation provides a stable foundation that can be incrementally enhanced.

**Consider Other TLDs**: If `.smi` continues to cause confusion, we could potentially use a different suffix (like `.smorg` for "Spokane Mountaineers Organization"). However, this would require a true username migration, which has the same global uniqueness challenges.

## Related Documentation

- [Configure Custom Login Page](../how-to-guides/configure-custom-login-page.md) - User guide for setup
- [Simplifying Custom Login Experience](../articles/simplifying-custom-login-experience.md) - Blog-style overview
- [Enable Google Login](../articles/enable-google-login.md) - Google OAuth setup

## Code References

**Main Components**:
- `force-app/main/default/pages/CommunitiesLogin.page`
- `force-app/main/default/classes/CommunitiesLoginController.cls`
- `force-app/main/default/classes/CommunitiesLoginControllerTest.cls`
- `force-app/main/default/pages/CommunitiesForgotPassword.page`
- `force-app/main/default/classes/CommunitiesForgotPasswordController.cls`
- `force-app/main/default/classes/CommunitiesForgotPasswordControllerTest.cls`

**Configuration**:
- `force-app/main/default/labels/CustomLabels.labels-meta.xml`
- `force-app/main/default/profiles/Spokane Mountaineers Profile.profile-meta.xml`
