# Enabling Google Login for Spokane Mountaineers Members

*Published: December 2025 | Category: Experience Cloud Enhancements*

## The Problem We Solved

Our members were asking for a simpler way to log in to the Spokane Mountaineers website. Many of them already use Google accounts for other services, and having to remember yet another password was becoming a barrier to accessing our community portal.

We wanted to enable "Sign in with Google" functionality while ensuring that:
- Only existing members could use it (no bypassing our Donorbox registration process)
- The login would reliably match members to their existing accounts
- Members would get clear guidance if something went wrong

## Our Solution: Google OAuth with Smart Account Matching

We implemented Google OAuth authentication that allows members to sign in using their Google account, but only if they already have a membership account created through our Donorbox registration process.

### How It Works

When a member clicks "Sign in with Google" on our login page:

1. **They authenticate with Google** - Google verifies their identity
2. **We match their account** - Our system looks up their existing membership account using their email address
3. **They're logged in** - If a match is found, they're automatically signed in to their account

### Why We Use Username Matching

We match member accounts by username pattern rather than email address. This approach provides several advantages:

- **Usernames can't be changed** - Once set, they remain constant
- **Email addresses can change** - Members might update their email in Salesforce but still use their old Google account
- **More predictable** - We always know the format: `email@example.com.smi`

This ensures that even if a member updates their email address in Salesforce, they can still log in with their Google account as long as their username follows the expected pattern.

## What Members Experience

### For Existing Members

If you already have a membership account:

1. Click **"Sign in with Google"** on the login page
2. Choose your Google account
3. You're automatically logged in!

The system recognizes your account and signs you in seamlessly.

### For New Members

If you don't have a membership account yet:

1. Click **"Sign in with Google"** on the login page
2. Choose your Google account
3. You'll see a helpful message directing you to:
   - Sign up through [Donorbox](https://donorbox.org/spokanemountaineers-membership-2) if you're a new member
   - Contact [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) if you already have an account but are having trouble

This ensures that new memberships still go through our proper registration and payment process via Donorbox.

### If Something Goes Wrong

If you have an account but Google login isn't working:

1. **Use your regular login** - Your standard username/password login still works
2. **Contact support** - Email [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) and we'll help you link your Google account

## Benefits for Members

- **One less password to remember** - Use your existing Google account
- **Faster login** - No need to type username and password
- **Secure** - Google handles authentication securely
- **Convenient** - Works on any device where you're signed into Google

## Technical Details

For technical implementation details, see our [Google Login Automation documentation](../automation/google-login-automation.md).

## Future Improvements

We're always looking to improve the member experience. Potential future enhancements include:

- Support for additional authentication providers
- Automatic account linking for existing members
- Enhanced error messages for edge cases

## Questions or Issues?

If you have questions about Google login or encounter any issues, please contact our tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).

