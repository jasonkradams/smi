/**
 * Google Apps Script: User Sync Core Logic (Admin SDK v1)
 * Receives a list of active users and syncs them with Google Workspace.
 */

const ADMIN_EMAIL = "jason.k.r.adams@gmail.com";
const TARGET_OU = "/IdP Only Users";
const PROTECTED_EMAILS = new Set([
  "webdev5@spokanemountaineers.org",
  "admin@spokanemountaineers.org",
  "jason.k.r.adams_gmail.com@spokanemountaineers.org"
]);
const DRY_RUN = false;
const DEBUG = false;

function doPost(e) {
  let createdCount = 0;
  let updatedCount = 0;
  let deletedCount = 0;
  let skippedDeleteCount = 0;

  try {
    const activeUsers = JSON.parse(e.postData.contents);
    const activeEmails = new Set(activeUsers.map(u => u.federation_id.toLowerCase()));

    const directory = AdminDirectory.Users;
    const existingUsers = directory.list({
      customer: "my_customer",
      maxResults: 500,
      orgUnitPath: TARGET_OU
    }).users || [];

    const existingEmails = new Set(existingUsers.map(u => u.primaryEmail.toLowerCase()));

    if (DEBUG) {
      const ous = AdminDirectory.Orgunits.list("my_customer", { type: "all" });
      if (ous.organizationUnits) {
        for (const ou of ous.organizationUnits) {
          Logger.log(`OU: ${ou.name}, Path: ${ou.orgUnitPath}`);
        }
      }
    }

    // Create or update users
    for (const user of activeUsers) {
      const email = user.federation_id.toLowerCase();
      const payload = {
        orgUnitPath: TARGET_OU,
        name: {
          givenName: user.first_name,
          familyName: user.last_name
        },
        customSchemas: {
          Mountaineers: {
            PublicEmail: user.email
          }
        },
        suspended: false
      };

      if (DEBUG) Logger.log(`Processing: ${email}`);

      if (existingEmails.has(email)) {
        if (DEBUG) Logger.log(`Updating: ${email}`);
        if (!DRY_RUN) directory.update(payload, email);
        updatedCount++;
      } else {
        const insertPayload = {
          ...payload,
          primaryEmail: email,
          password: generateRandomPassword()
        };
        if (DEBUG) Logger.log(`Creating: ${email}`);
        if (DEBUG) Logger.log(JSON.stringify(insertPayload));
        if (!DRY_RUN) directory.insert(insertPayload);
        createdCount++;
      }
    }

    // Delete users not in active list
    for (const user of existingUsers) {
      const email = user.primaryEmail.toLowerCase();
      if (!activeEmails.has(email)) {
        if (PROTECTED_EMAILS.has(email)) {
          if (DEBUG) Logger.log(`Protected user — skip delete: ${email}`);
          skippedDeleteCount++;
          continue;
        }
        if (user.orgUnitPath === TARGET_OU) {
          if (DEBUG) Logger.log(`Deleting: ${email}`);
          if (!DRY_RUN) directory.remove(email);
          deletedCount++;
        } else {
          if (DEBUG) Logger.log(`Outside OU — skip delete: ${email}`);
          skippedDeleteCount++;
        }
      }
    }

    Logger.log("Sync Summary:");
    Logger.log(`Created: ${createdCount}`);
    Logger.log(`Updated: ${updatedCount}`);
    Logger.log(`Deleted: ${deletedCount}`);
    Logger.log(`Skipped: ${skippedDeleteCount}`);

    return ContentService.createTextOutput("OK");
  } catch (err) {
    const summary = `Created: ${createdCount}\nUpdated: ${updatedCount}\nDeleted: ${deletedCount}\nSkipped: ${skippedDeleteCount}`;
    const body = `Error:\n${err.message}\n\nStack:\n${err.stack}\n\nSummary:\n${summary}`;
    Logger.log(body);
    sendAlert("[User Sync] Failure Detected", body);
    throw err;
  }
}

function generateRandomPassword() {
  return Math.random().toString(36).slice(-10) + "A1!";
}
