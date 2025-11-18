# Automation

This section documents internal automations and scheduled jobs used to manage membership, system syncs, and administrative workflows for Spokane Mountaineers.

Each automation is designed to reduce manual work, ensure consistency, and support the club’s online infrastructure.

---

## Included Jobs

- **[Scheduled: Add Members To Conservation Group](scheduled-add-members-to-conservation-group.md)**  
  Ensures all active site users are part of the Conservation Group and logs changes for audit.
- **[Notify Leader on RSVP](notify-leader-on-rsvp.md)**  
  Automatically sends email notifications to event leaders when someone RSVPs "Attending" to their event.
- [User Sync: Salesforce to Google Workspace](user-sync-google-workspace/index.md)  
  Automates the synchronization of active Salesforce members to Google Workspace accounts.
  - **[User Sync Flow](user-sync-google-workspace/salesforce-flow.md)**
  - **[Google Apps Script](user-sync-google-workspace/google-apps-script.md)**  
    A script that receives a list of active Salesforce members and synchronizes them to Google Workspace.
  - **[User Sync Checklist](user-sync-google-workspace/user-sync-testing-checklist.md)**  
    A checklist to verify the correct operation of the automated sync process.

---

More scheduled flows and automation tools will be added to this section as they are developed.
