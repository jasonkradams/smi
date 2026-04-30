# Enabling Microsoft Login for Spokane Mountaineers Members

_Published: April 2026 | Category: Experience Cloud Enhancements_

## The Problem We Solved

Members had been asking for a "Sign in with Microsoft" option to sit alongside the existing "Sign in with Google" button. Many members already use Microsoft accounts - work or school addresses, or personal `@outlook.com` / `@live.com` / `@hotmail.com` accounts - and a single-click sign-in is one less password to manage.

We wanted to enable Microsoft sign-in while ensuring that:

- Only existing members can use it (no bypassing our Donorbox registration process).
- The login reliably matches members to their existing accounts.
- Members get clear guidance if something goes wrong.

## Our Solution: Microsoft Identity Platform with Smart Account Matching

We implemented Microsoft OAuth authentication via the Microsoft Identity Platform (the same OpenID Connect-based service that powers "Sign in with Microsoft" across the web). Members can sign in with any Microsoft account, but only if they already have a membership account created through our Donorbox registration process.

### How It Works

When a member clicks "Continue with Microsoft" on our login page:

1. **They authenticate with Microsoft** - Microsoft verifies their identity.
2. **We match their account** - Our system looks up their existing membership account using their email address (or, for accounts without a verified email, the user principal name Microsoft sends back).
3. **They're logged in** - If a match is found, they're automatically signed in.

### Why We Use Username Matching

We match member accounts by username pattern rather than email address - the same approach as our Google sign-in. Advantages:

- **Usernames can't be changed** - Once set, they remain constant.
- **Email addresses can change** - Members might update their email in Salesforce but still use their old Microsoft account.
- **More predictable** - We always know the format: `email@example.com.smi`.

### Microsoft-specific behavior

Some Microsoft accounts don't have a verified email claim. For those accounts, the Microsoft Identity Platform sends the user principal name (UPN) instead of an email. Our handler tries `email` first and falls back to the UPN, so these members can still sign in.

## What Members Experience

### For Existing Members

If you already have a membership account:

1. Click **"Continue with Microsoft"** on the login page.
2. Choose your Microsoft account.
3. You're automatically logged in.

### For New Members

If you don't have a membership account yet:

1. Click **"Continue with Microsoft"** on the login page.
2. Choose your Microsoft account.
3. You'll see a helpful message directing you to:
    - Sign up through [Donorbox](https://donorbox.org/spokanemountaineers-membership-2) if you're a new member.
    - Contact [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) if you already have an account but are having trouble.

### If Something Goes Wrong

If you have an account but Microsoft login isn't working:

1. **Use your regular login** - Your standard username/password login still works.
2. **Try Google sign-in** - If you also have a Google account on file, that route works the same way.
3. **Contact support** - Email [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) and we'll help you link your Microsoft account.

## Benefits for Members

- **One less password to remember** - Use your existing Microsoft account.
- **Faster login** - No need to type username and password.
- **Works with any Microsoft account** - Personal, work, or school.
- **Secure** - Microsoft handles authentication.

## Technical Details

For technical implementation details, see our [Microsoft Login Automation documentation](../automation/microsoft-login-automation.md). The Microsoft Entra App Registrations that back this feature are managed as code in our [infrastructure repository](https://github.com/Spokane-Mountaineers/infrastructure) - this is the first feature to live in that repo.

## Questions or Issues?

If you have questions about Microsoft login or encounter any issues, please contact our tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
