# Google Apps Script for User Sync with Google Workspace

## Purpose

This script receives a list of **active Salesforce members** and synchronizes them to Google Workspace by:

* Creating accounts in the IdP Only Users OU if they don’t exist
* Updating user information if needed
* Suspending accounts not present in the received list

## Requirements

* Google Workspace domain with admin privileges
* Service account with domain-wide delegation
* Apps Script published as a Web App (with Anyone access or restricted to the domain)

## Setup

### 1. Create a Google Apps Script

1. Go to [https://script.google.com/](https://script.google.com/)
2. Create a new script project
3. Replace the default code with the script below

### 2. Script Code (Basic Example)

```javascript
const ADMIN_EMAIL = "admin@yourdomain.org"; // Must be super admin
const TARGET_OU = "/IdP Only Users";

function doPost(e) {
const activeUsers = JSON.parse(e.postData.contents);
const activeEmails = new Set(activeUsers.map(u => u.federationId));

const existingUsers = AdminDirectory.Users.list({
    customer: "my_customer",
    maxResults: 500,
    query: `orgUnitPath='${TARGET_OU}'`
}).users || [];

// Update or create users
for (const user of activeUsers) {
    try {
    const existing = AdminDirectory.Users.get(user.federationId);
    AdminDirectory.Users.update({
        orgUnitPath: TARGET_OU,
        name: {
        givenName: user.firstName,
        familyName: user.lastName
        },
        suspended: false
    }, user.federationId);
    } catch (err) {
    // User not found, create
    AdminDirectory.Users.insert({
        primaryEmail: user.federationId,
        orgUnitPath: TARGET_OU,
        name: {
        givenName: user.firstName,
        familyName: user.lastName
        },
        password: Math.random().toString(36).slice(-8),
    });
    }
}

// Suspend users not in active list
for (const user of existingUsers) {
    if (!activeEmails.has(user.primaryEmail)) {
    AdminDirectory.Users.update({
        suspended: true
    }, user.primaryEmail);
    }
}

return ContentService.createTextOutput("OK");
}
```

**Note:** Ensure the service account has impersonation rights for ADMIN_EMAIL.

### 3. Enable APIs

In the Apps Script project:

* Go to **Services > Add a Service**
* Add **Admin SDK** (AdminDirectory)

Also, enable it in Google Cloud Console:

* Enable **Admin SDK API**
* Set up **OAuth Consent Screen**
* Set up **Domain-wide Delegation**

⠀
### 4. Deploy as Web App

1 Click **Deploy > Manage deployments**
2 Choose **Web App**
	* Execute as: **Me**
	* Who has access: **Anyone** or **Anyone in domain**
3 Deploy and copy the URL for use in Salesforce Named Credential

⠀
### 5. Scopes Required

Add the following scopes to your manifest (appsscript.json):
```json
{
  "oauthScopes": [
    "https://www.googleapis.com/auth/admin.directory.user",
    "https://www.googleapis.com/auth/admin.directory.orgunit",
    "https://www.googleapis.com/auth/script.external_request",
    "https://www.googleapis.com/auth/script.scriptapp"
  ]
}
```

## Security Considerations

* Restrict Web App access if possible
* Use a validation token if needed
* Rotate passwords or default values for new users
