# Migrating to Email-Based Login: Supporting `.smi` Username Suffix Transparently

## The Challenge

When our Salesforce Experience Cloud site was created, we faced a significant constraint: Salesforce requires usernames to be globally unique across all Salesforce organizations worldwide. According to [Salesforce documentation](https://help.salesforce.com/s/articleView?id=sf.basics_intro_usernames_passwords.htm), this remains a current platform requirement.

### Our Original Solution

To ensure our members had unique usernames in this global namespace, we made a pragmatic decision: append `.smi` to every member's email address. For example, a member with email `jane.smith@gmail.com` would receive the username `jane.smith@gmail.com.smi`.

While this approach guaranteed global uniqueness, it created member confusion. Members didn't understand why they needed to add `.smi` to their email when logging in, leading to failed login attempts and support requests.

## The Updated Solution

Rather than trying to migrate away from `.smi` usernames (which isn't viable), we're taking a different approach: **make the `.smi` suffix transparent to members**.

### The New User Experience

Members can now log in using either format:

- **Just their email**: `jane.smith@gmail.com`
- **Email with .smi suffix**: `jane.smith@gmail.com.smi`

Behind the scenes, our custom authentication pages detect whether the user included `.smi` and automatically append it if needed before authenticating with Salesforce.

### Why We Need Custom Pages

Salesforce's default Experience Cloud login page doesn't allow custom scripting or input transformation. We couldn't intercept the username field to add the `.smi` suffix automatically. This limitation meant we needed to build our own authentication pages.

## Our Solution: Custom Login and Forgot Password Pages

We implemented custom Visualforce pages for both login and password reset that automatically append the `.smi` suffix if members don't include it:

### Custom Login Page

The `CommunitiesLogin` Visualforce page with `CommunitiesLoginController` intercepts the login form submission and normalizes the username:

```apex
// Add .smi suffix if not present for authentication
if (!username.endsWithIgnoreCase('.smi')) {
  username = username + '.smi';
}
```

This means whether a member enters `jane.smith@gmail.com` or `jane.smith@gmail.com.smi`, they'll successfully authenticate with the correct Salesforce username.

### Custom Forgot Password Page

Similarly, the `CommunitiesForgotPassword` page handles password reset requests with the same normalization logic. Members can request a password reset using either format, and the system will find their account.

### Benefits of This Approach

1. **Transparent to Members**: Members can use their email address without thinking about `.smi`
2. **No Database Migration**: Usernames remain as-is in Salesforce (with `.smi` suffix)
3. **Backward Compatible**: Members who still type `.smi` out of habit aren't affected
4. **No Training Required**: Members naturally try their email address first
5. **Consistent Experience**: Both login and password reset work the same way

## Implementation Details

The custom pages provide additional benefits beyond username normalization:

- Modern, responsive design matching our brand
- Loading states during authentication
- Password visibility toggle for better usability
- Google OAuth integration
- Alpine.js for smooth interactivity
- Custom labels for easy URL management

Both pages include comprehensive test coverage (`CommunitiesLoginControllerTest` and `CommunitiesForgotPasswordControllerTest`) to ensure reliability.

## Technical Implementation

The solution follows Salesforce best practices:

- Visualforce pages with `without sharing` controllers for unauthenticated access
- Username normalization using `endsWithIgnoreCase()` to detect suffix
- Automatic `.smi` appending when not present
- Proper error handling with user-friendly messages
- Test classes achieving 100% code coverage
- Responsive design using modern CSS and Alpine.js

## What This Solves

### Before

- Members confused about needing to add `.smi`
- Support requests for "forgot how to log in"
- Members trying `email@domain.com` and failing
- Inconsistent user experience

### After

- Members enter their email address naturally
- System handles `.smi` suffix automatically
- Both formats work seamlessly
- Improved user experience without database changes

## Lessons Learned

This project highlights an important principle: **always verify platform constraints before planning migrations**.

Our initial research suggested Salesforce had removed the global username uniqueness requirement. However, deeper investigation revealed this constraint still exists. Rather than abandoning the project, we pivoted to a solution that improves the user experience without requiring changes to the underlying data.

Sometimes the best solution isn't to change the data model—it's to make the existing model more user-friendly.

## Next Steps

### Phase 1 (Complete)

- Custom login and forgot password pages with `.smi` appending logic
- Guest user profile configuration for page access
- Custom labels for maintenance-free URL updates
- Full test coverage

### Phase 2 (Planned)

- Deploy custom pages to production
- Monitor member login patterns
- Update new member creation process to ensure clarity that `.smi` is auto-appended
- Update member documentation to reflect that they can use just their email

### Phase 3 (Future)

- Consider whether to update member-facing documentation to explain the `.smi` convention
- Monitor for any edge cases or issues
- Potentially add helpful tooltips explaining the username format

---

**Related Documentation:**

- [Configure Custom Login Page Guide](../how-to-guides/configure-custom-login-page.md)
- [Custom Login Implementation Details](../implementation/custom-login-page-implementation.md)
