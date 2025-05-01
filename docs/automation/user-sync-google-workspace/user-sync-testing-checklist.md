# Testing Checklist: Salesforce to Google Workspace User Sync

This checklist helps verify the correct operation of the automated sync process between Salesforce and Google Workspace.

## 🔄 Pre-Deployment Validation

### ✅ Google Workspace Setup

- [X] Verify "IdP Users Only" OU exists
- [ ] Create a test user manually to confirm admin privileges
- [ ] Enable Admin SDK API in the associated Google Cloud project
- [ ] Add Admin SDK service in Apps Script project
- [ ] Set up domain-wide delegation and validate impersonation

### ✅ Google Apps Script

- [ ] Script deployed as a Web App (test URL manually)
- [ ] Proper scopes set in `appsscript.json`
- [ ] `doPost()` correctly parses example JSON input
- [ ] Use `Logger.log()` or `console.log()` to confirm data flow during tests

### ✅ Salesforce Setup

- [ ] **Named Credential** configured with correct endpoint
- [ ] **Scheduled Flow** filters active members correctly
- [ ] Flow correctly maps and serializes JSON payload
- [ ] Test callout works manually (via Flow debug or Apex)

## 🔬 Dry Run (Manual Tests)

- [ ] Use a single known active user in test payload
- [ ] Confirm Google Workspace account is created or updated in `IdP Users Only`
- [ ] Add a second user, run sync again — both should be present
- [ ] Remove first user from active list, run sync — user should be deleted

## 🛡️ Fault and Edge Case Handling

- [ ] Invalid federation ID → logged gracefully, not fatal
- [ ] Missing federation ID/name fields → logged, user skipped
- [ ] Google API failure → caught and logged (does not halt loop)
- [ ] Retry flow handles partial failures (e.g., retry next day)

## 🧪 Daily Job Verification

- [ ] Enable schedule (e.g., daily)
- [ ] Logs show successful sync and account updates
- [ ] Suspended users are removed from `IdP Users Only`
- [ ] New active members appear automatically

## 📝 Post-Deployment Monitoring

- [ ] Enable email alerts for Apps Script failures
- [ ] Audit user creation/suspension logs weekly
- [ ] Spot-check OU for stale users monthly
