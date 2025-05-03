/**
 * Test Functions for User Sync
 */

function testSendAlert() {
  sendAlert("[TEST] Sync Alert Test", "This is a test alert from Google Apps Script.");
}

function resetAlertThrottle() {
  PropertiesService.getScriptProperties().deleteProperty("lastAlertTime");
}

function testDoPost() {
  resetAlertThrottle()
  const mockData = {
    email: "jason.k.r.adams@gmail.com",
    first_name: "Jason",
    last_name: "Adams",
    federation_id: "jason.k.r.adams_gmail.com@spokanemountaineers.org"
  };

  const mockEvent = {
    postData: {
      contents: JSON.stringify([mockData])
    }
  };

  const result = doPost(mockEvent);
  Logger.log(result.getContent());
}

function testListAllUsers() {
  const users = AdminDirectory.Users.list({
    customer: "my_customer",
    maxResults: 100
  });
  for (const user of users.users || []) {
    Logger.log(`${user.primaryEmail} - ${user.orgUnitPath}`);
  }
}

function testListOrgUnits() {
  const ous = AdminDirectory.Orgunits.list("my_customer", { type: "all" });
  if (ous.organizationUnits) {
    for (const ou of ous.organizationUnits) {
      Logger.log(`OU: ${ou.name}, Path: ${ou.orgUnitPath}`);
    }
  } else {
    Logger.log("No OUs found.");
  }
}
