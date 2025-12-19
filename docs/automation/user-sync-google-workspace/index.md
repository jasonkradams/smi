# User Sync: Salesforce to Google Workspace

This automation ensures that only **active** members of the Spokane Mountaineers have user accounts in **Google Workspace**, and that:

- All active users are placed in the **`IdP Users Only`** organizational unit (OU)
- Inactive users are **suspended or removed** from Google Workspace

## Overview

The architecture relies on Salesforce Flows and Google Apps Script, requiring no external server or infrastructure.

![Architecture Diagram](./flow_diagram.svg)

## Components

### Salesforce Org

- **Scheduled Flow:** Queries all members where `User.IsActive == "True"`
- **Named Credential:** Configured to securely send data to a Google Apps Script endpoint via HTTP

### Google Workspace

- **Google Apps Script Web App:** Receives a list of active members and compares it to the users in the `IdP Users Only` OU
- **Google Workspace Admin SDK:** Used by the script to create, update, suspend, or delete user accounts

## Sync Behavior

| Case                                                  | Action                       |
| ----------------------------------------------------- | ---------------------------- |
| User is Active in Salesforce but not in Google        | **Create** Workspace account |
| User is Active in both                                | **NoOp**                     |
| User is not Active in Salesforce but exists in Google | **Delete** account           |

## File Structure for Docs

```
automation/user-sync-google-workspace/
├── index.md                    # Overview of automation goals & approach
├── sync-architecture.md        # Diagram + flow description
├── salesforce-flow.md          # Flow config and Named Credential steps
├── google-apps-script.md       # Google script, scopes, and deployment
├── testing-checklist.md        # Manual dry-run instructions
```
