# Salesforce Flow for User Synchronization with Google Workspace

## Purpose

This scheduled Flow identifies all active members in Salesforce and sends their user details to a Google Apps Script endpoint for account synchronization.

## Requirements

- **Custom field**: `User.FederationIdentifier` (used as username/email in Google Workspace)
- **Membership status field**: e.g., `User.IsActive`
- **Named Credential** configured to securely call the Google Web App endpoint

## Steps

### 1. Create a Named Credential

1. Navigate to **Setup > Named Credentials**
2. Create a new credential:
    - Label: `Google Workspace Webhook`
    - Name: `Google_Workspace_Webhook`
    - URL: `https://script.google.com/macros/s/XXXXX/exec` (your script URL)
    - Identity Type: Anonymous (or Named Principal if using token)
    - Generate Authorization Header: false

### 2. Define an External Credential (if using OAuth)

1. Go to **External Credentials** under Setup
2. Define scopes for your Google Apps Script endpoint (optional)

### 3. Create the Scheduled Flow

- Object: `User`
- Filter: `User.IsActive Equals 'True'`
- Fields to collect:
    - First Name
    - Last Name
    - Federation ID (used as the Workspace username)

### 4. Add an HTTP Callout Action

- Drag in the **Action** element > Select **Send HTTP Request**
- Use the Named Credential: `Google_Workspace_Webhook`
- Method: `POST`
- Body: Build JSON from Flow variables (loop over records to build a list)

```json
[
  {
    "email": "first.last@example.com",
    "firstName": "First",
    "lastName": "Last",
    "federationId": "first.last@example.com.smi"
  },
  ...
]
```

### 5. Handle Errors and Logging

- Optionally log HTTP responses
- Use fault paths to handle connection issues

### 6. Schedule the Flow

- Set to run daily (or as needed)
