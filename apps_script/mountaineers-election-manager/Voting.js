const TOKEN_FIELD_LABEL = "Voting Token";
const VOTE_STATUS_HEADER = "Vote Status";

function processVote(e) {
  if (!e || !e.range) {
    Logger.log(
      "This function must be triggered by a form submission, not run manually."
    );
    return;
  }

  const sheet = e.range.getSheet();
  const submittedRow = e.range.getRow();
  const ss = sheet.getParent();
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

  const tokenColIndex = headers.indexOf(TOKEN_FIELD_LABEL);
  if (tokenColIndex === -1) return;

  const normalizeToken = (t) => t.toString().trim().toLowerCase();

  const tokenCell = sheet.getRange(submittedRow, tokenColIndex + 1);
  const submittedToken = normalizeToken(tokenCell.getValue());

  // Add "Vote Status" column to the response sheet if it doesn't exist yet
  let statusColIndex = headers.indexOf(VOTE_STATUS_HEADER);
  if (statusColIndex === -1) {
    statusColIndex = sheet.getLastColumn();
    sheet.getRange(1, statusColIndex + 1).setValue(VOTE_STATUS_HEADER);
  }
  const statusCol = statusColIndex + 1;

  const registry = ss.getSheetByName("Token Registry");
  if (!registry) return;

  const registryData =
    registry.getLastRow() > 1
      ? registry.getRange(2, 1, registry.getLastRow() - 1, 2).getValues()
      : [];

  let registryRowNumber = -1;
  let alreadyUsed = false;

  for (let i = 0; i < registryData.length; i++) {
    if (normalizeToken(registryData[i][0]) === submittedToken) {
      registryRowNumber = i + 2;
      alreadyUsed = registryData[i][1] === true;
      break;
    }
  }

  if (registryRowNumber === -1) {
    flagRow(sheet, submittedRow, statusCol, tokenCell, "INVALID TOKEN");
    return;
  }

  if (alreadyUsed) {
    flagRow(sheet, submittedRow, statusCol, tokenCell, "DUPLICATE");
    return;
  }

  registry.getRange(registryRowNumber, 2).setValue(true);
  writeCleanVote(
    ss,
    sheet,
    headers,
    submittedRow,
    tokenColIndex,
    statusColIndex
  );
  sheet.getRange(submittedRow, statusCol).setValue("VALID");
  tokenCell.setValue("[used]");
}

function writeCleanVote(
  ss,
  sheet,
  headers,
  submittedRow,
  tokenColIndex,
  statusColIndex
) {
  const excludedIndices = new Set([tokenColIndex, statusColIndex]);
  const resultsSheet = ss.getSheetByName("Vote Results");

  const cleanHeaders = headers.filter(
    (_, i) => !excludedIndices.has(i) && headers[i] !== VOTE_STATUS_HEADER
  );
  if (resultsSheet.getLastRow() <= 1)
    resultsSheet
      .getRange(1, 1, 1, cleanHeaders.length)
      .setValues([cleanHeaders]);

  const rowValues = sheet
    .getRange(submittedRow, 1, 1, headers.length)
    .getValues()[0];
  const cleanVote = rowValues.filter((_, i) => !excludedIndices.has(i));
  resultsSheet.appendRow(cleanVote);
}

function flagRow(sheet, row, statusCol, tokenCell, status) {
  sheet.getRange(row, statusCol).setValue(status);
  tokenCell.setValue("[rejected]");
}
