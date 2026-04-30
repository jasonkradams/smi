# Microsoft Login Automation

This document describes the technical implementation of Microsoft OAuth authentication for the Spokane Mountaineers Experience Cloud site, backed by the Microsoft Identity Platform (OpenID Connect / OAuth 2.0 v2.0).

---

## Access

- Apex Class: [MicrosoftAuthRegistrationHandler](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/MicrosoftAuthRegistrationHandler.cls)
- Test Class: [MicrosoftAuthRegistrationHandlerTest](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/classes/MicrosoftAuthRegistrationHandlerTest.cls)
- Auth Provider: Setup → Identity → Auth. Providers → **Microsoft**
- Microsoft Entra App Registration: managed by Terraform/OpenTofu in [`Spokane-Mountaineers/infrastructure`](https://github.com/Spokane-Mountaineers/infrastructure) - see `terraform/environments/{staging,production}/` and the [infrastructure plan](https://github.com/Spokane-Mountaineers/infrastructure/blob/main/plans/sign-in-with-microsoft.md).

---

## Purpose

The `MicrosoftAuthRegistrationHandler` implements Salesforce's `Auth.RegistrationHandler` interface to manage user authentication for "Sign in with Microsoft" on Experience Cloud sites. It:

- Authenticates existing users via Microsoft OAuth.
- Matches users by username pattern (`email + '.smi'`).
- Falls back to the UPN (`data.username`) when Microsoft returns an empty `email` claim.
- Prevents new account creation (Donorbox-only registration).
- Provides actionable error messages for users.

---

## Configuration

### Prerequisites

1. **My Domain** is deployed.
2. **Microsoft Entra App Registration** exists for the target environment, managed in the infrastructure repo. The first apply produces a `client_id` and `client_secret` used below.
3. **Microsoft Auth Provider** is configured in the Salesforce org with:
    - Provider Type: Open ID Connect
    - URL Suffix: `Microsoft`
    - Consumer Key: `client_id` from `tofu output -raw client_id`
    - Consumer Secret: `client_secret` from `tofu output -raw client_secret`
    - Authorize Endpoint URL: `https://login.microsoftonline.com/common/oauth2/v2.0/authorize`
    - Token Endpoint URL: `https://login.microsoftonline.com/common/oauth2/v2.0/token`
    - User Info Endpoint URL: `https://graph.microsoft.com/oidc/userinfo`
    - Default Scopes: `openid email profile`
    - Registration Handler: `MicrosoftAuthRegistrationHandler`
4. **Experience Cloud Site** has:
    - Microsoft Auth Provider enabled in Login & Registration settings
    - Self-Registration disabled (to prevent bypassing Donorbox)

### Setup Steps

1. **Provision the Entra App Registration** (infrastructure repo):

    ```bash
    cd infrastructure/terraform/environments/staging
    tofu init
    tofu apply -var-file=terraform.tfvars      # first pass with placeholder callback URL
    tofu output -raw client_id
    tofu output -raw client_secret             # sensitive
    ```

    See [`docs/bootstrap.md`](https://github.com/Spokane-Mountaineers/infrastructure/blob/main/docs/bootstrap.md) for the one-time GCS state-backend and `az login` setup.

2. **Configure Microsoft Auth Provider** (Salesforce):
    - Navigate to: Setup → Identity → Auth. Providers → New
    - Provider Type: Open ID Connect
    - Use the values from step 1 plus the endpoint URLs listed under Prerequisites
    - Assign Registration Handler: `MicrosoftAuthRegistrationHandler`
    - Set "Execute Registration As" to a user with appropriate permissions
    - Save. Salesforce generates the **Callback URL**.

3. **Update Entra App with the real callback URL** (infrastructure repo):
    - Edit `infrastructure/terraform/environments/staging/terraform.tfvars` and set `salesforce_callback_url` to the value Salesforce just generated.
    - Re-run `tofu apply -var-file=terraform.tfvars`. The redirect URI is updated in place.

4. **Enable for Experience Cloud Site**:
    - Navigate to: Setup → Digital Experiences → All Sites → **Spokane Mountaineers** → Administration → Login & Registration
    - Under Authentication Providers, enable **Microsoft**
    - Confirm Self-Registration is **Disabled**

5. **Add to Login Page**:
    - The login page is `force-app/main/default/pages/CommunitiesLogin.page`. The "Continue with Microsoft" button is wired to `{!microsoftLoginUrl}` and ships with the Apex deploy.

---

## Implementation Details

### User Matching Strategy

Identical to the Google handler - username pattern matching:

```apex
String resolvedEmail = String.isNotBlank(data.email) ? data.email : data.username;
String usernamePattern = resolvedEmail.toLowerCase().trim() + '.smi';
List<User> usersByUsername = [
    SELECT Id, Username, Email, IsActive
    FROM User
    WHERE Username = :usernamePattern
    LIMIT 1
];
```

### Microsoft-Specific: UPN Fallback

Microsoft Identity Platform returns user data via the OIDC userinfo endpoint. For most accounts the `email` claim and the UPN match. For some Entra accounts the `email` claim is empty (the account has no verified email), but the UPN - which Salesforce surfaces as `data.username` - is populated and looks like an email address. The handler falls back to `data.username` when `data.email` is blank so these users can still sign in.

### Account Creation Prevention

Same contract as the Google handler - no new accounts are created. If no matching user is found:

```apex
throw new RegistrationHandlerException(
    'No account found. New members: sign up at donorbox.org/spokanemountaineers-membership-2. ' +
    'Existing members: contact webdev@spokanemountaineers.org to link your Microsoft account.'
);
```

---

## Flow Diagram

![Microsoft Login Flow Diagram](microsoft-login-flow.svg)

_Source: [microsoft-login-flow.d2](microsoft-login-flow.d2)_

Render with `d2 microsoft-login-flow.d2 microsoft-login-flow.svg`.

---

## Code Structure

### Main Methods

#### `createUser(Id portalId, Auth.UserData data)`

Main entry point called by Salesforce during Microsoft OAuth flow.

**Logic:**

1. Resolve `data.email`; if blank, fall back to `data.username` (UPN).
2. If still blank, throw `RegistrationHandlerException('Email is required for authentication')`.
3. Call `findExistingUser()` to locate user by username pattern.
4. If found, return the user.
5. If not found, throw exception with Donorbox / webdev guidance.

#### `findExistingUser(String email)`

Builds `email.toLowerCase().trim() + '.smi'` and queries the `User` table for a matching `Username`. Returns the first match or `null`.

#### `updateUser(Id userId, Id portalId, Auth.UserData data)`

No-op. Existing flows handle user updates.

---

## Testing

### Test Coverage

`MicrosoftAuthRegistrationHandlerTest` mirrors `GoogleAuthRegistrationHandlerTest` with one additional test:

- **`testCreateUser_FallsBackToUpnWhenEmailBlank`** - verifies that when Microsoft returns an empty `email` claim with a populated UPN, the handler resolves the user via the UPN.

### Running Tests

```bash
sf apex run test --class-names MicrosoftAuthRegistrationHandlerTest --target-org staging --code-coverage
```

---

## Error Handling

### No Account Found

**User sees:**

```
No account found. New members: sign up at donorbox.org/spokanemountaineers-membership-2.
Existing members: contact webdev@spokanemountaineers.org to link your Microsoft account.
```

### Blank Email

**User sees:**

```
Email is required for authentication
```

This is reached only when both `data.email` and `data.username` are empty, which is rare in practice.

---

## Maintenance

### Rotating the client secret

The `azuread_application_password` resource has a one-year `end_date_relative`. To rotate before expiry:

```bash
cd infrastructure/terraform/environments/staging
tofu taint module.salesforce_microsoft_signin.azuread_application_password.this
tofu apply -var-file=terraform.tfvars
tofu output -raw client_secret
```

Then update the **Consumer Secret** field in Setup → Auth. Providers → Microsoft.

### Updating the Username Pattern

If the `.smi` suffix is removed in the future, update the username pattern in `MicrosoftAuthRegistrationHandler.cls` (and `GoogleAuthRegistrationHandler.cls`). Both handlers use the same pattern.

---

## Performance

- Single SOQL query per login attempt.
- Indexed `Username` field; `LIMIT 1`.

---

## Security Considerations

- **Account Creation Prevention** - Self-Registration must remain Disabled in the Experience Cloud site.
- **Username matching** - Username is immutable, so authentication is stable across email changes.
- **Tenant audience** - `common` allows any Microsoft account. The handler does not trust the tenant - it relies on the matching user already existing in Salesforce.
- **Client secret** - stored only in Terraform/OpenTofu state (GCS, encrypted, versioned, ACL-restricted) and in Salesforce Auth Provider configuration. Never committed to source.

---

## Related Documentation

- [Microsoft Login Article](../articles/enable-microsoft-login.md) - user-friendly overview
- [Google Login Automation](google-login-automation.md) - sibling provider with the same matching strategy
- [Infrastructure repo plan](https://github.com/Spokane-Mountaineers/infrastructure/blob/main/plans/sign-in-with-microsoft.md) - Azure side
- [Auth.RegistrationHandler Interface](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_auth_registration_handler.htm)

---

## Troubleshooting

### Microsoft Button Not Appearing

1. Verify the Microsoft Auth Provider is enabled for the Experience Cloud site.
2. Verify the `microsoftLoginUrl` getter is wired up in `CommunitiesLoginController`.
3. Check browser console for errors.

### Login Fails for Existing User

1. Verify the user's Salesforce username follows the pattern `email@example.com.smi`.
2. Check that `IsActive = true` on the user.
3. Review debug logs for the resolved email and the username pattern that was queried.
4. If the Microsoft account has no verified email, confirm `data.username` (UPN) matches the user's Salesforce username minus the `.smi` suffix - that's what the fallback uses.

### Redirect URI Mismatch

If Azure rejects the callback with `AADSTS50011: redirect URI mismatch`:

1. Compare the URL Salesforce shows in Setup → Auth Providers → Microsoft → Callback URL with `tofu output -raw client_id`'s app registration's `web.redirect_uris`.
2. Update `salesforce_callback_url` in the relevant `terraform.tfvars` and re-apply.

---

## Support

For issues or questions about Microsoft login automation:

- **Email**: [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org)
- **GitHub Issues** (Salesforce side): [smi/issues](https://github.com/jasonkradams/smi/issues/new)
- **GitHub Issues** (Infrastructure side): [infrastructure/issues](https://github.com/Spokane-Mountaineers/infrastructure/issues/new)
