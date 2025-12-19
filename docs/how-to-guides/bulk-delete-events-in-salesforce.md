# How To: Bulk Delete Events in Salesforce

When a user accidentally creates a large number of recurring Events (e.g., hundreds of records), manually deleting them one by one is not practical. This guide shows how to identify and bulk delete Events safely using Salesforce tools.

---

## Delete Events Using Developer Console (SOQL Query)

1. **Open the Developer Console**
    - In Salesforce, click the **⚙️ (Setup gear)** in the top right.
    - Select **Developer Console**.

    ![Developer Console](../assets/images/salesforce%20open%20developer%20console.png)

2. **Open the Query Editor**
    - In the Developer Console, go to the bottom panel → **Query Editor** tab.

    ![Query Editor](../assets/images/salesforce%20dev%20console%20query%20editor.png)

3. **Run a SOQL Query to Identify Records**
    - Example query:
        ```sql
        SELECT Id, Subject, ActivityDate, CreatedById
        FROM Event
        WHERE Subject LIKE '%%Bad Event Subject%%'
        ```
    - Replacing `%%Bad Event Subject%%` with the actual subject or criteria of the unwanted Events.
    - Add filters such as `Subject LIKE '%Meeting%'` or `ActivityDate >= 2025-09-01` to narrow results.

4. **Review the Results**
    - Confirm you’re only pulling the unwanted Events.
    - Export results if you want a record for audit.

5. **Delete the Records**
    - Copy the list of Ids and use **Data Loader** or **Workbench (see below)** to bulk delete.
    - Alternatively, use **Execute Anonymous** with Apex (advanced).
      ![Delete the Records](../assets/images/salesforce%20execute%20soql%20query.png)

## Optional: Delete In The Event Registration Table

If the event has not yet been approved then it will be in the Event Registration table. You can and sholud delete it from there as well.

1. **Open the Developer Console**
    - In Salesforce, click the **⚙️ (Setup gear)** in the top right.
    - Select **Developer Console**.

    ![Developer Console](../assets/images/salesforce%20open%20developer%20console.png)

2. **Open the Query Editor**
    - In the Developer Console, go to the bottom panel → **Query Editor** tab.
      ![Query Editor](../assets/images/salesforce%20dev%20console%20query%20editor.png)

3. **Run a SOQL Query to Identify Records**
    - Example query:
        ```sql
        SELECT ID, Status__c, Start__c, Name
        FROM Event_Registration__c
        WHERE Name LIKE '%%Evening Hike at James T Slavin%%'
        ```
    - Replacing `%%Evening Hike at James T Slavin%%` with the actual subject or criteria of the unwanted Events.
    - Add filters such as `Name LIKE '%Meeting%'` or `Start__c >= 2025-09-01` to narrow results.
4. **Review the Results**
    - Confirm you’re only pulling the unwanted Event Registrations.
    - Export results if you want a record for audit.
5. **Delete the Records**
    - Select the records you want to delete, then cick the **Delete Row** button.
      ![Delete the Records](../assets/images/salesforce%20query%20editor%20delete%20row%20button.png)
