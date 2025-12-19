# Google Apps Script: User Sync Endpoint

This script serves as the backend for syncing active members from Salesforce into Google Workspace. It is deployed as a Web App and receives an HTTP POST request from Salesforce containing the list of users to sync.

## Responsibilities

- Accept POST requests with JSON payload of active users
- Compare incoming list with current users in the `IdP Users Only` OU
- Create missing users
- Update existing user info and OU placement
- Suspend users no longer marked active in Salesforce

## Files in this Folder

```
automations/user-sync-google-workspace/google-app-script/
├── index.md               # This overview file
├── script.gs              # Main logic for handling sync
├── alerts.gs              # Optional alerting logic for errors
├── appsscript.json        # Manifest with required scopes
```

## Permissions & Scopes

You must:

- Enable the **Admin SDK API** in your Google Cloud project
- Add the following scopes to your manifest:

```json
{
    "oauthScopes": [
        "https://www.googleapis.com/auth/admin.directory.user",
        "https://www.googleapis.com/auth/admin.directory.orgunit",
        "https://www.googleapis.com/auth/script.external_request",
        "https://www.googleapis.com/auth/script.scriptapp",
        "https://www.googleapis.com/auth/gmail.send" // if using alerting
    ]
}
```

## Deployment Steps

1. Open Google Apps Script: [https://script.google.com](https://script.google.com)
2. Add the required files and scopes
3. Click **Deploy > Manage Deployments > New Deployment**
    - Choose type **Web App**
    - Execute as: **Me**
    - Who has access: **Anyone** (or domain-only)
4. Copy the Web App URL for use in your Salesforce Named Credential

---

See [`user_sync.js`](./user_sync.js) and [`alerts.js`](./alerts.js) for implementation details.
