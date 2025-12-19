# Google Login Automation

This document describes the technical implementation of Google OAuth authentication for the Spokane Mountaineers Experience Cloud site.

---

## Access

* Apex Class: [GoogleAuthRegistrationHandler](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/GoogleAuthRegistrationHandler.cls)
* Test Class: [GoogleAuthRegistrationHandlerTest](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/GoogleAuthRegistrationHandlerTest.cls)
* Auth Provider: Setup → Identity → Auth. Providers → **Google**

---

## 🎯 Purpose

The `GoogleAuthRegistrationHandler` implements Salesforce's `Auth.RegistrationHandler` interface to manage user authentication for Google OAuth login on Experience Cloud sites. It:

- Authenticates existing users via Google OAuth
- Matches users by username pattern (`email + '.smi'`)
- Prevents new account creation (Donorbox-only registration)
- Provides actionable error messages for users

---

## ⚙️ Configuration

### Prerequisites

1. **My Domain** must be deployed
2. **Google Auth Provider** must be configured with:
   - Consumer Key and Secret from Google Cloud Console
   - Scopes: `openid email profile`
   - Registration Handler: `GoogleAuthRegistrationHandler`
3. **Experience Cloud Site** must have:
   - Google Auth Provider enabled in Login & Registration settings
   - Social Login component added to the Login page
   - Self-Registration disabled (to prevent bypassing Donorbox)

### Setup Steps

1. **Configure Google Auth Provider**:
   - Navigate to: Setup → Identity → Auth. Providers → **Google**
   - Assign Registration Handler: `GoogleAuthRegistrationHandler`
   - Set "Execute Registration As" to a user with appropriate permissions

2. **Enable for Experience Cloud Site**:
   - Navigate to: Setup → Digital Experiences → All Sites → **Spokane Mountaineers** → Administration → Login & Registration
   - Under Authentication Providers, enable **Google**
   - Under Registration, set **Self-Registration** to **Disabled**

3. **Add Social Login Component**:
   - Open Experience Builder for your site
   - Navigate to the Login page
   - Add the **Social Login** component
   - Publish changes

---

## 🧱 Implementation Details

### User Matching Strategy

The handler uses **username pattern matching** for reliable user identification:

```apex
String usernamePattern = email.toLowerCase().trim() + '.smi';
List<User> usersByUsername = [
    SELECT Id, Username, Email, IsActive
    FROM User
    WHERE Username = :usernamePattern
    LIMIT 1
];
```

**Why username pattern matching?**

- **Usernames cannot be modified** - Provides a stable identifier for authentication
- **Email addresses can change** - Members might update their email in Salesforce, but username remains constant
- **Single query** - Efficient database lookup using indexed Username field
- **Predictable format** - Always follows `email@example.com.smi` pattern

### Account Creation Prevention

The handler **does not create new accounts**. If no matching user is found, it throws an exception with actionable guidance:

```apex
if (!usersByUsername.isEmpty()) {
    return usersByUsername[0];
}

// No user found - provide actionable guidance
throw new RegistrationHandlerException(
    'No account found for this email address.\n\n' +
    'If you are a new member, please sign up at:\n' +
    'https://donorbox.org/spokanemountaineers-membership-2\n\n' +
    'If you already have an account, please:\n' +
    '1. Use your usual login method for now\n' +
    '2. Report this issue to webdev@spokanemountaineers.org\n\n' +
    'We will help you link your Google account to your existing membership.'
);
```

This ensures that:
- New memberships go through Donorbox (payment required)
- Existing members get clear guidance on next steps
- No duplicate accounts are created

---

## 📊 Flow Diagram

![Google Login Flow Diagram](google-login-flow.svg)

*Source: [google-login-flow.d2](google-login-flow.d2)*

---

## 🔍 Code Structure

### Main Methods

#### `createUser(Id portalId, Auth.UserData data)`

Main entry point called by Salesforce during Google OAuth flow.

**Parameters:**
- `portalId`: Network (Experience Cloud site) ID
- `data`: User data from Google OAuth callback (includes email, firstName, lastName)

**Returns:** `User` record if found, throws exception if not found

**Logic:**
1. Validates email is present
2. Calls `findExistingUser()` to locate user
3. If found, returns user
4. If not found, throws exception with actionable guidance

#### `findExistingUser(String email)`

Finds existing user by username pattern.

**Parameters:**
- `email`: Email address from Google OAuth

**Returns:** `User` record if found, `null` if not found

**Logic:**
1. Constructs username pattern: `email.toLowerCase().trim() + '.smi'`
2. Queries User table for matching username
3. Returns first match or `null`

#### `updateUser(Id userId, Id portalId, Auth.UserData data)`

Called when user data needs updating (not used in this implementation).

**Note:** This method intentionally does nothing. Existing flows handle user updates automatically.

---

## 🧪 Testing

### Test Coverage

The test class `GoogleAuthRegistrationHandlerTest` provides **100% code coverage** with 22 test methods covering:

- User matching by username pattern
- Error handling for blank emails
- Error handling for non-existent users
- Helper method testing (alias generation, password generation, etc.)

### Running Tests

```bash
sf apex run test --class-names GoogleAuthRegistrationHandlerTest --target-org smi --code-coverage
```

### Test Scenarios

1. **Existing User Found**: Verifies successful login when username pattern matches
2. **User Not Found**: Verifies exception is thrown with actionable error message
3. **Blank Email**: Verifies exception is thrown for invalid input
4. **Edge Cases**: Tests helper methods with various inputs

---

## 🚨 Error Handling

### Common Error Scenarios

#### No Account Found

**User sees:**
```
No account found for this email address.

If you are a new member, please sign up at:
https://donorbox.org/spokanemountaineers-membership-2

If you already have an account, please:
1. Use your usual login method for now
2. Report this issue to webdev@spokanemountaineers.org

We will help you link your Google account to your existing membership.
```

**Resolution:**
- New members: Direct to Donorbox signup
- Existing members: Contact webdev for account linking assistance

#### Blank Email

**User sees:**
```
Email is required for authentication
```

**Resolution:** This should not occur in normal operation. If it does, contact webdev.

---

## 🔧 Maintenance

### Updating Username Pattern

If the `.smi` suffix is removed in the future, update line 96 in `GoogleAuthRegistrationHandler.cls`:

**Current:**
```apex
String usernamePattern = email.toLowerCase().trim() + '.smi';
```

**Future (if .smi removed):**
```apex
String usernamePattern = email.toLowerCase().trim();
```

### Adding Additional Auth Providers

To add support for additional OAuth providers (e.g., Microsoft, Facebook):

1. Create new Auth Provider in Setup
2. Create new Registration Handler class (or extend existing)
3. Assign handler to Auth Provider
4. Enable provider in Experience Cloud site settings

### Monitoring

Monitor for:
- Failed login attempts (check debug logs)
- User-reported issues (webdev@spokanemountaineers.org)
- Exception frequency (Salesforce debug logs)

---

## 📈 Performance

### Query Optimization

- **Single SOQL query** per login attempt
- **Indexed field** (Username) for fast lookups
- **LIMIT 1** to minimize data transfer
- Efficient database lookup with minimal overhead

---

## 🔐 Security Considerations

### Account Creation Prevention

- Self-Registration must be **disabled** in Experience Cloud settings
- Handler explicitly throws exceptions instead of creating users
- Donorbox remains the only account creation path

### User Matching

- Username pattern matching provides a stable authentication identifier
- Usernames cannot be modified, preventing account hijacking
- Email changes don't break authentication since matching is based on username

### Error Messages

- Error messages are user-friendly but don't expose system internals
- Clear guidance directs users to appropriate support channels

---

## 📝 Related Documentation

- [Google Login Article](../articles/enable-google-login.md) - User-friendly overview
- [Experience Cloud Setup](https://help.salesforce.com/s/articleView?id=sf.networks_communities_setup.htm) - Salesforce documentation
- [Auth.RegistrationHandler Interface](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_auth_registration_handler.htm) - Salesforce Apex documentation

---

## 🐛 Troubleshooting

### Google Button Not Appearing

1. Verify Auth Provider is enabled for the Experience Cloud site
2. Check that Social Login component is added to Login page
3. Verify Self-Registration settings (should be disabled)
4. Check browser console for JavaScript errors

### Login Fails for Existing User

1. Verify user's username follows pattern: `email@example.com.smi`
2. Check that user is active (`IsActive = true`)
3. Review debug logs for exception details
4. Verify email from Google matches username pattern

### Exception Messages Not Showing

1. Check Salesforce debug logs for full exception details
2. Verify error handling in Experience Cloud login component
3. Test with different browsers/devices

---

## 📞 Support

For issues or questions about Google login automation:

- **Email**: [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org)
- **GitHub Issues**: [Create an issue](https://github.com/jasonkradams/smi/issues/new)

