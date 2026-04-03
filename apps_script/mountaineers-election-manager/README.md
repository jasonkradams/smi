# Spokane Mountaineers Election Manager

A Google Apps Script Web App for creating, distributing, and validating Spokane Mountaineers secret-ballot elections.

---

## Project Structure

| File              | Purpose                                                                                            |
| ----------------- | -------------------------------------------------------------------------------------------------- |
| `Main.js`         | Entry point (`doGet`), routing, election CRUD, lock/unlock logic                                   |
| `Factory.js`      | Creates the spreadsheet, Google Form, folder structure, and triggers for a new election            |
| `Distribution.js` | Generates UUID tokens and emails personalized voting links to members                              |
| `Voting.js`       | `processVote` trigger — validates tokens, marks them used, writes anonymized votes to Vote Results |
| `Security.js`     | Manages a persistent `EMAIL_SALT` and SHA-256 hashing for privacy-safe Sent Log entries            |
| `Index.html`      | Bootstrap 5 administrative dashboard                                                               |
| `appsscript.json` | Manifest — declares OAuth scopes, runtime version, and webapp settings                             |

---

## Architecture

### 1. UI (`Index.html`)

A gated single-page app built with Bootstrap 5.

- **Gateway**: the user chooses **Create New Election** or **Manage Existing Election** before any form fields appear.
- **Create flow**: enter title, start/close dates, target Drive folder, ballot questions (chip inputs), and member email list, then click Create.
- **Manage flow**: select an election from a `year/Name` dropdown to load all data back into the same fields. A lock banner appears when the start date has passed (yellow = locked, red = closed).
- **Distribution card**: appears after an election is created or loaded; triggers the token email send.

Key UI patterns:

- **Chip inputs** for ballot candidates (Enter, comma, or paste to add; click × to remove).
- **Email textarea** with live counter and on-blur deduplication/validation summary.
- **Lock state**: fields and inputs are disabled once the election start date is reached. An unlock checkbox prompts a confirmation dialog and fires `sendUnlockNotification`. After the close date the election is permanently read-only.

### 2. Election Creation (`Factory.js`)

`createNewElection` does all of this in one call:

1. Creates a Google Spreadsheet (`<title> - Election Data`) and a Google Form (`<title>`).
2. Links the form to the spreadsheet as its response destination.
3. Sets up tabs: **Member Emails**, **Sent Log**, **Token Registry**, **Vote Results**.
4. Adds ballot questions (MC or Checkbox) with `normalizeCandidates` (title-case + dedup) applied to every candidate list.
5. Writes a hidden **Settings** sheet with `VOTING_FORM_URL`, `TOKEN_ENTRY_ID`, `ELECTION_START_DATE`, `ELECTION_CLOSE_DATE`.
6. Calls `applyChoiceShuffle` to enable per-load randomization on every choice question via the Forms REST API.
7. Moves the spreadsheet and form into the target Drive subfolder.
8. Attaches an `onFormSubmit` trigger pointing at `processVote`.

### 3. Distribution (`Distribution.js`)

Generates a UUID token per member, stores it in **Token Registry**, and sends an email containing a pre-filled form URL (`?entry.<TOKEN_ENTRY_ID>=<uuid>`). Hashes the email address with SHA-256 + salt before writing to **Sent Log** so the log contains no PII.

### 4. Vote Validation (`Voting.js`)

`processVote` fires on every form submission:

1. Reads the submitted token from the **Voting Token** field.
2. Looks it up in **Token Registry**.
3. If invalid → marks row `INVALID TOKEN`, replaces token cell with `[rejected]`.
4. If already used → marks row `DUPLICATE`, replaces token cell with `[rejected]`.
5. If valid → marks token used in registry, copies the anonymized vote (no token, no status column) to **Vote Results**, marks row `VALID`, replaces token cell with `[used]`.

### 5. Candidate Shuffle (`applyChoiceShuffle` in `Main.js`)

The `FormApp` service does not expose a shuffle flag for choice questions. Shuffle is instead enabled via a `batchUpdate` call to the **Forms REST API v1**, which sets `choiceQuestion.shuffle: true` on every MC/Checkbox item. This means Google shuffles the choices on every form load — no script-side randomization needed.

This call is made:

- After `_buildQuestions` in `Factory.js` (new election).
- After all three update passes in `updateElectionBallot` in `Main.js` (editing an existing election).

---

## OAuth Scopes (`appsscript.json`)

| Scope              | Why                                                             |
| ------------------ | --------------------------------------------------------------- |
| `spreadsheets`     | Read/write election spreadsheets                                |
| `drive`            | Move files, browse folder hierarchy                             |
| `forms`            | Create and edit Google Forms via `FormApp`                      |
| `forms.body`       | Required by the Forms REST API `batchUpdate` endpoint (shuffle) |
| `gmail.send`       | Send token emails and unlock notifications                      |
| `script.scriptapp` | Create `onFormSubmit` triggers programmatically                 |

---

## Google Cloud Project

The script is backed by a dedicated GCP project that owns the OAuth consent screen and API enablement. This is required because Apps Script's auto-generated `sys-` projects are owned by a Google service account — you cannot enable APIs or configure OAuth on them yourself.

|                |                                   |
| -------------- | --------------------------------- |
| Project ID     | `spokane-mountaineers-forms-mgr`  |
| Project number | `726875656290`                    |
| Organization   | `spokanemountaineers.org`         |
| Owner          | `webdev5@spokanemountaineers.org` |

### APIs enabled on this project

| API                     | Why                                        |
| ----------------------- | ------------------------------------------ |
| `forms.googleapis.com`  | Forms REST API (`batchUpdate` for shuffle) |
| `drive.googleapis.com`  | Browse and move files in Drive             |
| `sheets.googleapis.com` | Read/write election spreadsheets           |
| `gmail.googleapis.com`  | Send token emails and unlock notifications |
| `script.googleapis.com` | Apps Script execution                      |

### Re-linking Apps Script to this project

If the Apps Script project is ever reset or cloned, re-link it to this GCP project:

1. Open the Apps Script editor → gear icon (**Project Settings**)
2. Scroll to **Google Cloud Platform (GCP) Project** → click **Change project**
3. Enter project number: **`726875656290`** → click **Set project**
4. Run any function manually (e.g. `getElectionFolders`) to trigger the OAuth consent flow and grant all required scopes

### OAuth consent screen

The consent screen is configured as **Internal** (restricted to `spokanemountaineers.org` accounts). If it ever needs to be reconfigured:

1. Open: `https://console.cloud.google.com/apis/credentials/consent?project=spokane-mountaineers-forms-mgr`
2. User type: **Internal**
3. App name: `Spokane Mountaineers Forms Manager`
4. Support + developer contact email: `webdev5@spokanemountaineers.org`
5. Save and Continue through Scopes and Summary — no manual scope additions needed

### Managing APIs via gcloud CLI

```bash
# List enabled APIs
gcloud services list --project=spokane-mountaineers-forms-mgr --enabled

# Enable an additional API
gcloud services enable <api>.googleapis.com --project=spokane-mountaineers-forms-mgr

# Grant a new admin Owner access
gcloud projects add-iam-policy-binding spokane-mountaineers-forms-mgr \
  --member="user:<email>" \
  --role="roles/owner"
```

---

## Setup & Deployment

### First-time authorization

Open the Apps Script editor and manually run `getElectionFolders` once. This triggers the Google OAuth consent screen so all required scopes are granted before the first web app deployment.

### Deploy as a Web App

1. **Deploy** > **New Deployment** > **Web App**.
2. **Execute as**: Me.
3. **Who has access**: Anyone with a Google Account (or restrict to your domain).
4. Copy the web app URL and share with election administrators.

After any code change, create a new deployment version — editing the existing deployment does not update the live URL's code.

### Local development with clasp

```bash
npm install -g @google/clasp
# Enable the Apps Script API at script.google.com/home/usersettings
clasp login
clasp clone "<SCRIPT_ID>"   # pull existing project
clasp push                   # push local changes
```

---

## Drive Folder Structure

```
Elections/  (root ID: 1Ysm0ysOQfTt3K5YzXMctBC5voffoz1tk)
  2025/
    Officers Election - Election Data   (Spreadsheet)
    Officers Election                   (Form)
  2026/
    Board Election - Election Data
    Board Election
```

The root folder ID is hardcoded in `Main.js` (`getElections`, `getElectionFolders`) and `Factory.js` (`_resolveFolder`). Update all three if the root folder changes.

> **TODO**: If the club moves to a Google Workspace Shared Drive, update the `DriveApp.getFolderById()` logic in `Factory.js` and `Main.js` to ensure the script has "Organizer" access to the Shared Drive.

---

## Email Quotas

| Account type                              | Daily send limit |
| ----------------------------------------- | ---------------- |
| Personal Gmail                            | 100 emails/day   |
| Google Workspace (standard or non-profit) | 2,000 emails/day |

For a member list of ~1,000 addresses, a Google Workspace account is required.
