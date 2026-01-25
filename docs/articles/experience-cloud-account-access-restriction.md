# Restricting Member Access to Account Records in Experience Cloud

_Published: January 2026 | Category: Experience Cloud Enhancements_

## The Problem We Discovered

We recently identified a privacy concern on our member website. Members could use the global search feature to view **Account records** belonging to other members. For example, searching for "Adams" would return results like "Adams Household," exposing sensitive internal data such as:

- Member Type
- Donation Amounts
- Other administrative information

This information should only be visible to system administrators, not regular members browsing the site.

## Our Solution: Profile-Level Access Control

We resolved this issue by removing **Read access to the Account object** for all member-facing Experience Cloud profiles. This ensures that Account records are no longer visible or searchable for members on the website, while internal staff access remains unchanged.

### Affected Profiles

The following Experience Cloud profiles were updated to remove Account object read access:

- SM Community Plus Chair
- SM Community Plus Login
- SM Community Plus Member

## What Members Experience

### Before the Fix

- Global search could return Account records for other members
- Members could view household information and donation data
- Internal administrative data was inadvertently exposed

### After the Fix

- Account records no longer appear in search results
- Members can still access their own profile and contact information
- Only system administrators can view Account records
- Member functionality remains otherwise unchanged

## Technical Implementation

For each affected profile, we followed these steps:

1. Navigate to **Setup → Profiles**
2. Select the profile name (e.g., "SM Community Plus Member")
3. Go to **Object Settings → Account**
4. Click **Edit**
5. Uncheck the **"Read"** permission
6. Click **Save**

This simple configuration change immediately prevents members from viewing any Account records through the Experience Cloud interface.

## Why This Matters

### Privacy Protection

Member financial information and household details are sensitive data that should be protected. This fix ensures that:

- Donation amounts remain private
- Household structures are not exposed
- Member types and classifications are internal-only information

### Security Best Practices

Following the principle of least privilege, members should only have access to the data they need to use the site effectively. Account-level information is administrative in nature and not necessary for the member experience.

### Compliance

Protecting member financial data aligns with data privacy best practices and helps maintain member trust in our systems.

## Benefits

- **Enhanced Privacy** - Member financial data is no longer exposed through search
- **Improved Security** - Reduced access surface area for sensitive information
- **No Impact on Functionality** - Members retain all necessary access for normal site usage
- **Future-Proof** - This configuration will apply to any new Experience Cloud profiles created using these templates

## Verification

To verify this fix is working correctly:

1. Log in as a member user (using one of the affected profiles)
2. Use the global search to search for a common member name
3. Confirm that no Account records appear in the results
4. Verify that Contact records and other relevant objects still appear as expected

## Questions or Concerns?

If you notice any issues with member access or have questions about this security enhancement, please contact our tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
