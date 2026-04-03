/**
 * Sends unique tokens to members listed in the election spreadsheet.
 * ssId is passed explicitly from the UI, enabling concurrent elections.
 */
function distributeTokens(ssId) {
  const salt =
    PropertiesService.getScriptProperties().getProperty("EMAIL_SALT");

  const ss = SpreadsheetApp.openById(ssId);
  const settings = readElectionSettings(ss);
  const formUrl = settings["VOTING_FORM_URL"];
  const entryId = settings["TOKEN_ENTRY_ID"];
  const closeDate = settings["ELECTION_CLOSE_DATE"];

  const memberSheet = ss.getSheetByName("Member Emails");
  const emails = memberSheet
    .getRange(2, 1, memberSheet.getLastRow() - 1, 1)
    .getValues();
  const sentLog = ss.getSheetByName("Sent Log");
  const registry = ss.getSheetByName("Token Registry");

  emails.forEach((row) => {
    const email = row[0].toString().trim();
    if (!email) return;

    const hash = Security.computeHash(email.toLowerCase() + salt);
    const token = Utilities.getUuid();
    const body = `Hello,\n\nYour Spokane Mountaineers voting token is: ${token}\n\nVote here: ${formUrl}?${entryId}=${token}\n\nVoting closes: ${closeDate}`;

    try {
      GmailApp.sendEmail(email, "Spokane Mountaineers Election", body);
      sentLog.appendRow([hash, new Date()]);
      registry.appendRow([token, false, new Date()]);
    } catch (e) {
      Logger.log("Failed: " + email);
    }
  });
}
