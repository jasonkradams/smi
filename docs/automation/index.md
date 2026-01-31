# Automation

This section documents internal automations and scheduled jobs used to manage membership, system syncs, and administrative workflows for Spokane Mountaineers.

Each automation is designed to reduce manual work, ensure consistency, and support the club’s online infrastructure.

---

## Included Jobs

- **[Event Approval Email Alerts](event-approval-email-alerts.md)**  
  Email alerts that notify activity group committee chairs when new events are submitted for approval. Covers all 9 activity groups with explicit email alert configuration.
- **[Google Login Automation](google-login-automation.md)**  
  Technical implementation of Google OAuth authentication for Experience Cloud, including user matching strategy, account creation prevention, and error handling.
- **[Scheduled: Add Members To Conservation Group](scheduled-add-members-to-conservation-group.md)**  
  Ensures all active site users are part of the Conservation Group and logs changes for audit.
- **[Notify Leader on RSVP](notify-leader-on-rsvp.md)**  
  Automatically sends email notifications to event leaders when someone RSVPs "Attending" to their event.
- **[Automated License Sorting](../proposals/automate-member-license-sorting.md)**  
  Automatically optimizes Salesforce Community license usage by assigning Premium licenses to users with >5 logins (up to 475 max), and Login licenses to others. Tracks full fiscal year login history via custom object and runs daily to maintain optimal license distribution.

---

More scheduled flows and automation tools will be added to this section as they are developed.
