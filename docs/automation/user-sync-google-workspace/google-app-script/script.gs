/**
 * Google Apps Script: User Sync Core Logic
 * Receives a list of active users and syncs them with Google Workspace.
 */

const ADMIN_EMAIL = "webdev5@spokanemountaineers.org";
const TARGET_OU = "/IdP Users Only";

function doPost(e) {
  let createdCount = 0;
  let updatedCount = 0;
  let deletedCount = 0;
  let skippedDeleteCount = 0;

  try {
    const activeUsers = JSON.parse(e.postData.contents);
    const activeEmails = new Set(activeUsers.map(u => u.federationId.toLowerCase()));

    const existingUsers = AdminDirectory.Users.list({
      customer: "my_customer",
      maxResults: 500,
      query: `orgUnitPath='${TARGET_OU}'`
    }).users || [];

    const existingEmails = new Set(existingUsers.map(u => u.primaryEmail.toLowerCase()));

    // Create or update users
    for (const user of activeUsers) {
      const email = user.federationId.toLowerCase();
      const payload = {
        orgUnitPath: TARGET_OU,
        name: {
          givenName: user.firstName,
          familyName: user.lastName
        },
        suspended: false
      };

      if (existingEmails.has(email)) {
        AdminDirectory.Users.update(payload, email);
        updatedCount++;
      } else {
        AdminDirectory.Users.insert({
          ...payload,
          primaryEmail: email,
          password: generateRandomPassword()
        });
        createdCount++;
      }
    }

    // Delete users not in active list, but only if they are still in TARGET_OU
    for (const user of existingUsers) {
      const email = user.primaryEmail.toLowerCase();
      if (!activeEmails.has(email)) {
        if (user.orgUnitPath === TARGET_OU) {
          AdminDirectory.Users.remove(email);
          deletedCount++;
        } else {
          Logger.log(`Skipped deletion for user ${email} (outside managed OU: ${user.orgUnitPath})`);
          skippedDeleteCount++;
        }
      }
    }

    Logger.log(`User Sync Summary:`);
    Logger.log(`Created: ${createdCount}`);
    Logger.log(`Updated: ${updatedCount}`);
    Logger.log(`Deleted: ${deletedCount}`);
    Logger.log(`Skipped Deletion (outside OU): ${skippedDeleteCount}`);

    return ContentService.createTextOutput("OK");

  } catch (err) {
    const summary = `Created: ${createdCount}\nUpdated: ${updatedCount}\nDeleted: ${deletedCount}\nSkipped Deletion (outside OU): ${skippedDeleteCount}`;
    const body = `Error:\n${err.message}\n\nStack:\n${err.stack}\n\nSync Summary:\n${summary}`;
    sendAlert("[User Sync] Failure Detected", body);
    throw err;
  }
}

function generateRandomPassword() {
  return Math.random().toString(36).slice(-10) + "A1!";
}