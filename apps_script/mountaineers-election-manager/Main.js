/**
 * Title-cases a string (each word capitalized).
 */
function toTitleCase(str) {
  return str
    .trim()
    .replace(
      /\S+/g,
      (w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()
    );
}

/**
 * Applies title case to each candidate name and removes case-insensitive duplicates.
 * Returns a new array; does not mutate the original.
 */
function normalizeCandidates(candidates) {
  const seen = new Set();
  return candidates
    .map((c) => toTitleCase(c))
    .filter((c) => {
      if (!c) return false;
      const key = c.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

/**
 * Uses the Forms REST API to enable per-load shuffle on every
 * MultipleChoice and Checkbox question in the given form.
 * Requires the https://www.googleapis.com/auth/forms.body OAuth scope
 * declared in appsscript.json.
 */
function applyChoiceShuffle(formId) {
  const baseUrl = "https://forms.googleapis.com/v1/forms/" + formId;
  const headers = { Authorization: "Bearer " + ScriptApp.getOAuthToken() };

  // Fetch the form via REST to get the IDs that batchUpdate actually accepts.
  // FormApp.Item.getId() returns an Apps Script internal ID that differs from
  // the Forms REST API itemId.
  const getRes = UrlFetchApp.fetch(baseUrl, {
    method: "get",
    headers: headers,
    muteHttpExceptions: true
  });
  if (getRes.getResponseCode() !== 200) {
    throw new Error(
      "Forms REST API error (" +
        getRes.getResponseCode() +
        "): " +
        getRes.getContentText()
    );
  }

  const formData = JSON.parse(getRes.getContentText());
  const requests = [];

  (formData.items || []).forEach((item, index) => {
    const cq =
      item.questionItem &&
      item.questionItem.question &&
      item.questionItem.question.choiceQuestion;
    if (!cq) return;

    requests.push({
      updateItem: {
        item: {
          itemId: item.itemId,
          questionItem: {
            question: {
              choiceQuestion: { shuffle: true }
            }
          }
        },
        location: { index: index },
        updateMask: "questionItem.question.choiceQuestion.shuffle"
      }
    });
  });

  if (requests.length === 0) return;

  const batchRes = UrlFetchApp.fetch(baseUrl + ":batchUpdate", {
    method: "post",
    contentType: "application/json",
    headers: headers,
    payload: JSON.stringify({ requests: requests }),
    muteHttpExceptions: true
  });
  if (batchRes.getResponseCode() !== 200) {
    throw new Error(
      "Forms REST API error (" +
        batchRes.getResponseCode() +
        "): " +
        batchRes.getContentText()
    );
  }
}

/**
 * Main Controller & Routing
 */

function doGet() {
  return HtmlService.createHtmlOutputFromFile("Index")
    .setTitle("Spokane Mountaineers Election Manager")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/**
 * Fetches existing subfolders inside the root Elections folder.
 */
function getElectionFolders() {
  const rootFolderId = "1Ysm0ysOQfTt3K5YzXMctBC5voffoz1tk";
  const list = [];
  try {
    const root = DriveApp.getFolderById(rootFolderId);
    const folders = root.getFolders();
    while (folders.hasNext()) {
      const f = folders.next();
      list.push({ id: f.getId(), name: f.getName() });
    }
    return list.sort((a, b) => b.name.localeCompare(a.name));
  } catch (e) {
    return [];
  }
}

/**
 * Reads per-election metadata from the hidden Settings sheet.
 * Used by both loadElection and distributeTokens.
 */
function readElectionSettings(ss) {
  const sheet = ss.getSheetByName("Settings");
  if (!sheet)
    throw new Error(
      "Settings sheet not found. This election may predate multi-election support."
    );
  const rows = sheet.getRange(1, 1, sheet.getLastRow(), 2).getValues();
  const settings = {};
  rows.forEach(([key, value]) => {
    if (!key) return;
    // Google Sheets coerces YYYY-MM-DD strings into Date objects on read-back.
    // Re-format them so callers always receive a plain YYYY-MM-DD string.
    if (value instanceof Date) {
      settings[key] = Utilities.formatDate(
        value,
        Session.getScriptTimeZone(),
        "yyyy-MM-dd"
      );
    } else {
      settings[key] = value.toString();
    }
  });
  return settings;
}

/**
 * Returns all elections across year subfolders as { ssId, name: "<year>/<election>" }.
 * An election is identified by a Google Sheet ending with " - Election Data".
 */
function getElections() {
  const rootFolderId = "1Ysm0ysOQfTt3K5YzXMctBC5voffoz1tk";
  const list = [];
  try {
    const root = DriveApp.getFolderById(rootFolderId);
    const yearFolders = root.getFolders();
    while (yearFolders.hasNext()) {
      const yearFolder = yearFolders.next();
      const yearName = yearFolder.getName();
      const files = yearFolder.getFilesByType(MimeType.GOOGLE_SHEETS);
      while (files.hasNext()) {
        const f = files.next();
        const fileName = f.getName();
        if (fileName.endsWith(" - Election Data")) {
          const electionName = fileName.slice(0, -" - Election Data".length);
          list.push({ ssId: f.getId(), name: yearName + "/" + electionName });
        }
      }
    }
    return list.sort((a, b) => b.name.localeCompare(a.name));
  } catch (e) {
    return [];
  }
}

/**
 * Loads an existing election by spreadsheet ID. Returns the ssId, metadata,
 * emails, and form questions to the UI for full state restoration.
 */
function loadElection(ssId) {
  const ss = SpreadsheetApp.openById(ssId);
  const settings = readElectionSettings(ss);

  // Title is the sheet name without the " - Election Data" suffix
  const title = ss.getName().replace(/ - Election Data$/, "");

  // Emails
  const memberSheet = ss.getSheetByName("Member Emails");
  const emails =
    memberSheet && memberSheet.getLastRow() > 1
      ? memberSheet
          .getRange(2, 1, memberSheet.getLastRow() - 1, 1)
          .getValues()
          .map((r) => r[0])
          .filter(Boolean)
      : [];

  // Read ballot questions from the paired Form in the same folder
  const questions = [];
  try {
    const folder = DriveApp.getFileById(ssId).getParents().next();
    const forms = folder.getFilesByType(MimeType.GOOGLE_FORMS);
    while (forms.hasNext()) {
      const f = forms.next();
      if (f.getName() === title) {
        FormApp.openById(f.getId())
          .getItems()
          .forEach((item) => {
            const type = item.getType();
            if (type === FormApp.ItemType.MULTIPLE_CHOICE) {
              questions.push({
                role: item.getTitle(),
                type: "multiple_choice",
                candidates: item
                  .asMultipleChoiceItem()
                  .getChoices()
                  .map((c) => c.getValue())
              });
            } else if (type === FormApp.ItemType.CHECKBOX) {
              questions.push({
                role: item.getTitle(),
                type: "checkbox",
                candidates: item
                  .asCheckboxItem()
                  .getChoices()
                  .map((c) => c.getValue())
              });
            }
            // TEXT items (e.g. Voting Token) are intentionally skipped
          });
        break;
      }
    }
  } catch (e) {
    // Non-fatal: questions will be empty if the form can't be read
  }

  // Ensure the salt exists (no-op if already set)
  Security.setupSalt();

  // Compute lock/closed state by comparing today's date string against stored dates.
  // YYYY-MM-DD strings compare correctly lexicographically, avoiding timezone issues.
  const today = Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    "yyyy-MM-dd"
  );
  const startDate = settings["ELECTION_START_DATE"] || "";
  const closeDate = settings["ELECTION_CLOSE_DATE"] || "";
  const isLocked = !!(startDate && today >= startDate);
  const isClosed = !!(closeDate && today > closeDate);

  return {
    ssId: ssId,
    title: title,
    formUrl: settings["VOTING_FORM_URL"],
    ssUrl: ss.getUrl(),
    emails: emails.join("\n"),
    startDate: startDate,
    closeDate: closeDate,
    isLocked: isLocked,
    isClosed: isClosed,
    questions: questions
  };
}

/**
 * Sends an email to webdev@spokanemountaineers.org when an in-progress election
 * is unlocked for editing via the web app.
 */
function sendUnlockNotification(ssId) {
  const ss = SpreadsheetApp.openById(ssId);
  const title = ss.getName().replace(/ - Election Data$/, "");
  const settings = readElectionSettings(ss);
  const startDate = settings["ELECTION_START_DATE"] || "unknown";
  const timestamp = Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    "yyyy-MM-dd HH:mm:ss z"
  );

  MailApp.sendEmail({
    to: "webdev@spokanemountaineers.org",
    subject: "Election Unlock Warning: " + title,
    body: [
      "An in-progress election has been unlocked for editing via the Election Manager.",
      "",
      "Election:    " + title,
      "Start Date:  " + startDate,
      "Unlocked At: " + timestamp,
      "",
      "Please verify that any changes made are intentional and authorized."
    ].join("\n")
  });
}

/**
 * Updates the ballot questions on the paired Google Form.
 * Existing MC/Checkbox items are updated in-place; items removed from the
 * new question list are deleted; new roles are appended.
 * The Voting Token text item is never touched.
 */
function updateElectionBallot(ssId, questions) {
  validateNoCrossPositionCandidates(questions);

  const ss = SpreadsheetApp.openById(ssId);
  const title = ss.getName().replace(/ - Election Data$/, "");

  // Locate the paired form
  const folder = DriveApp.getFileById(ssId).getParents().next();
  const forms = folder.getFilesByType(MimeType.GOOGLE_FORMS);
  let form = null;
  while (forms.hasNext()) {
    const f = forms.next();
    if (f.getName() === title) {
      form = FormApp.openById(f.getId());
      break;
    }
  }
  if (!form)
    throw new Error('Could not find the ballot form for "' + title + '".');

  // Build role → question map for O(1) lookup
  const questionMap = {};
  questions.forEach((q) => {
    questionMap[q.role] = q;
  });

  // Pass 1: update existing ballot items; collect items to remove
  const toDelete = [];
  const existingRoles = new Set();

  form.getItems().forEach((item) => {
    const type = item.getType();
    if (
      type !== FormApp.ItemType.MULTIPLE_CHOICE &&
      type !== FormApp.ItemType.CHECKBOX
    )
      return;

    const role = item.getTitle();
    existingRoles.add(role);

    if (questionMap[role]) {
      const normalized = normalizeCandidates(questionMap[role].candidates);
      if (type === FormApp.ItemType.MULTIPLE_CHOICE) {
        const mc = item.asMultipleChoiceItem();
        mc.setChoices(
          normalized.map((c) => mc.createChoice(c.trim()))
        ).setRequired(false);
      } else {
        const cb = item.asCheckboxItem();
        cb.setChoices(
          normalized.map((c) => cb.createChoice(c.trim()))
        ).setRequired(false);
      }
    } else {
      toDelete.push(item);
    }
  });

  // Pass 2: delete removed roles (must be outside the forEach)
  toDelete.forEach((item) => form.deleteItem(item));

  // Pass 3: append brand-new roles
  questions.forEach((q) => {
    if (existingRoles.has(q.role)) return;
    const normalized = normalizeCandidates(q.candidates);
    let item =
      q.type === "multiple_choice"
        ? form.addMultipleChoiceItem()
        : form.addCheckboxItem();
    item
      .setTitle(q.role)
      .setChoices(normalized.map((c) => item.createChoice(c.trim())))
      .setRequired(false);
  });

  // Enable per-load shuffle on all choice questions via the Forms REST API
  applyChoiceShuffle(form.getId());
}

/**
 * Overwrites the Member Emails sheet with a new list.
 * ssId is passed explicitly from the UI.
 */
function updateMemberEmails(ssId, emails) {
  const ss = SpreadsheetApp.openById(ssId);
  const sheet = ss.getSheetByName("Member Emails");
  if (!sheet) throw new Error("Member Emails sheet not found.");

  sheet.clearContents();
  const rows = [["Email"]].concat(emails.map((e) => [e]));
  sheet.getRange(1, 1, rows.length, 1).setValues(rows);
}

/**
 * Throws if any candidate name (after normalization) appears under more than one position.
 */
function validateNoCrossPositionCandidates(questions) {
  const seen = {}; // lowercase name -> position label
  const conflicts = [];
  questions.forEach((q) => {
    normalizeCandidates(q.candidates).forEach((name) => {
      const key = name.toLowerCase();
      if (seen[key] && seen[key] !== q.role) {
        conflicts.push(
          '"' +
            name +
            '" appears in both "' +
            seen[key] +
            '" and "' +
            q.role +
            '"'
        );
      } else if (!seen[key]) {
        seen[key] = q.role;
      }
    });
  });
  if (conflicts.length) {
    throw new Error(
      "Candidates may only appear on one position. " + conflicts.join("; ")
    );
  }
}

/**
 * Handles the payload from the GUI to start an election.
 */
function handleGuiSetup(payload) {
  try {
    Security.setupSalt();
    validateNoCrossPositionCandidates(payload.questions);
    return Factory.createNewElection(
      payload.title,
      payload.questions,
      payload.emails,
      payload.targetFolder,
      payload.startDate,
      payload.closeDate
    );
  } catch (e) {
    throw new Error("Setup Error: " + e.message);
  }
}
