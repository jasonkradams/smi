/**
 * Handles File/Folder Creation
 */
var Factory = {
  createNewElection: function (
    title,
    questions,
    emails,
    folderInfo,
    startDate,
    closeDate
  ) {
    // 0. Pre-flight: ensure no election with this name already exists in the target folder.
    //    Skip for new folders — they are empty by definition.
    if (!folderInfo.isNew) {
      const targetFolder = DriveApp.getFolderById(folderInfo.id);
      const existing = targetFolder.getFilesByType(MimeType.GOOGLE_SHEETS);
      while (existing.hasNext()) {
        if (existing.next().getName() === title + " - Election Data") {
          throw new Error(
            'An election named "' +
              title +
              '" already exists in this folder. ' +
              'Use "Manage Existing Election" to update it, or choose a different title.'
          );
        }
      }
    }

    // 1. Create Spreadsheet & Form
    const ss = SpreadsheetApp.create(title + " - Election Data");
    const ssId = ss.getId();
    const form = FormApp.create(title)
      .setDescription("Spokane Mountaineers Official Ballot")
      .setDestination(FormApp.DestinationType.SPREADSHEET, ssId);

    // 2. Setup "Member Emails" Tab
    const memberSheet = ss.insertSheet("Member Emails");
    const emailData = [["Email"]].concat(emails.map((e) => [e]));
    memberSheet.getRange(1, 1, emailData.length, 1).setValues(emailData);

    // Remove the default "Sheet1" that SpreadsheetApp.create() always adds
    const defaultSheet = ss.getSheetByName("Sheet1");
    if (defaultSheet) ss.deleteSheet(defaultSheet);

    // 3. Setup Helper Tabs
    const tabHeaders = {
      "Sent Log": ["Email Hash", "Sent At"],
      "Token Registry": ["Token", "Used", "Issued At"],
      "Vote Results": ["Timestamp"]
    };
    Object.entries(tabHeaders).forEach(([name, headers]) => {
      const tab = ss.getSheetByName(name) || ss.insertSheet(name);
      tab.getRange(1, 1, 1, headers.length).setValues([headers]);
    });

    // 4. Build Questions, Get Entry ID, and enable per-load shuffle
    const entryId = this._buildQuestions(form, questions);
    applyChoiceShuffle(form.getId());

    // 5. Write per-election metadata to a hidden Settings sheet
    const settingsSheet = ss.insertSheet("Settings");
    settingsSheet.getRange(1, 1, 4, 2).setValues([
      ["VOTING_FORM_URL", form.getPublishedUrl()],
      ["TOKEN_ENTRY_ID", entryId],
      ["ELECTION_START_DATE", startDate],
      ["ELECTION_CLOSE_DATE", closeDate]
    ]);
    settingsSheet.hideSheet();

    // 6. Move to Target Folder
    const folder = this._resolveFolder(folderInfo);
    DriveApp.getFileById(ssId).moveTo(folder);
    DriveApp.getFileById(form.getId()).moveTo(folder);

    // 7. Attach the Voting Trigger
    ScriptApp.newTrigger("processVote")
      .forSpreadsheet(ss)
      .onFormSubmit()
      .create();

    return {
      url: form.getPublishedUrl(),
      ssUrl: ss.getUrl(),
      ssId: ssId,
      title: title
    };
  },

  _buildQuestions: function (form, questions) {
    const tokenItem = form
      .addTextItem()
      .setTitle("Voting Token")
      .setRequired(true);
    questions.forEach((q) => {
      let item =
        q.type === "multiple_choice"
          ? form.addMultipleChoiceItem()
          : form.addCheckboxItem();
      const normalized = normalizeCandidates(q.candidates);
      item
        .setTitle(q.role)
        .setChoices(normalized.map((c) => item.createChoice(c.trim())))
        .setRequired(false);
    });
    const response = form.createResponse();
    response.withItemResponse(tokenItem.createResponse("TOKEN_PLACEHOLDER"));
    return response.toPrefilledUrl().match(/entry\.\d+/)[0];
  },

  _resolveFolder: function (info) {
    const rootId = "1Ysm0ysOQfTt3K5YzXMctBC5voffoz1tk";
    if (info.isNew) {
      return DriveApp.getFolderById(rootId).createFolder(info.newName);
    }
    return DriveApp.getFolderById(info.id);
  }
};
