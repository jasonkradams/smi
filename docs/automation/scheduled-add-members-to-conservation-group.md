# 🔄 Scheduled Flow: Add Members To Conservation Group

This scheduled Salesforce Flow ensures that all eligible site users (Community Users) are members of the **Conservation Chatter Group**, and logs each action for auditing.

---

## Access

- Flow: [Scheduled: Add Members To Conservation Group](https://spokanemountaineers.lightning.force.com/lightning/setup/Flows/page?address=%2F300Um00000l9gbFIAQ%3FretUrl%3D%2Flightning%2Fsetup%2FFlows%2Fhome)
- Logs: [Conservation Group Membership Logs](https://spokanemountaineers.lightning.force.com/lightning/o/Conservation_Group_Membership_Log__c/list?filterName=00BUm000001cEz4MAE)
- GitHub: [Scheduled_Add_Members_To_Conservation_Group.flow-meta.xml](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/flows/Scheduled_Add_Members_To_Conservation_Group.flow-meta.xml)

---

## 📆 Schedule

- **Runs Once** at **04:30 AM Pacific**
- Type: **Scheduled Flow**
- Trigger: **Platform-Scheduled**, not user-initiated

> _Note: This flow has been **deactivated** to ensure members who Opt Out of the Conservation group are not put back into teh group the next day._

---

## 🎯 Purpose

This Flow:

- Adds eligible users (active site users) to a specific Chatter Group (CollaborationGroup).
- Skips users who are already members of the group.
- Logs each operation (only added) into the `Conservation_Group_Membership_Log__c` object.
  Can be viewed here: [Conservation Group Membership Logs](https://spokanemountaineers.lightning.force.com/lightning/o/Conservation_Group_Membership_Log__c/list?filterName=00BUm000001cEz4MAE)

---

## 📋 Criteria for Eligible Users

The flow targets **active Community users**, defined as:

```plaintext
User.IsActive = true
AND (
  User.UserType = 'Customer Portal User' OR
  User.UserType = 'PowerCustomerSuccess' OR
  User.UserType = 'PowerPartner'
)
```

These users are queried via a Get Records element labeled **Get_User_Records**.

---

## 🧱 Flow Structure

### 1. Get Existing Group Memberships

- Retrieves all CollaborationGroupMember records for the **Conservation Group**.
- Group ID is hardcoded as: 0F91N000000m2jESAQ.

⠀2. Get Active Community Users

- Loads active site users matching the criteria above.

⠀3. Loop Through Each User

- For each user:
    - Filters existing memberships to check if the user is already in the group.
    - Uses a Decision node (Member in Group?) to branch:

---

## 🤖 Decision Logic

### ❌ If the user is not already a group member

- Assigns:
    - CollaborationGroupId = 0F91N000000m2jESAQ
    - MemberId = User.Id
    - CollaborationRole = Standard
- Adds the new member record to a collection for batch creation.
- Logs the action with:
    - Message\_\_c = "Added To Conservation Group"

⠀✅ If the user is already a member:

- Loops through their existing CollaborationGroupMember record(s)
- Logs the status:
    - Message\_\_c = "Already a Member"

---

## 📦 Record Creation

At the end of all processing:

- The flow **bulk-creates** all new CollaborationGroupMember records.
- It also **bulk-creates** all Conservation_Group_Membership_Log\_\_c log entries.

## 🛠 Key Variables and Resources

|           **Variable Name**            |                       **Type**                       |               **Description**               |
| :------------------------------------: | :--------------------------------------------------: | :-----------------------------------------: |
| `variable_collaboration_group_members` |        Collection of CollaborationGroupMember        |      Holds new group members to create      |
|   `variable_conservation_group_logs`   | Collection of Conservation_Group_Membership_Log\_\_c | Holds logs for both added and skipped users |
| `variable_collaboration_group_member`  |           Single CollaborationGroupMember            |        Template record used per user        |
|      `variable_conservation_log`       |    Single Conservation_Group_Membership_Log\_\_c     |      Template log record used per user      |

---

## 🧾 Logging Details

Each log record stores:

- User_ID\_\_c
- Username\_\_c
- Email\_\_c
- Group_Member_Id\_\_c
- Role\_\_c
- Updated_At\_\_c (timestamp)
- Message\_\_c: either "Added To Conservation Group" or "Already a Member"

---

## ⚠️ Edge Cases Handled

- Users not in the group are added and logged.
- Users already in the group are skipped.
- The Chatter Group ID is hardcoded to prevent accidental misrouting.
- Only users who are **eligible site users** are processed.

---

## 📈 Monitoring & Auditing

Admins can monitor execution by:

- Querying the Conservation_Group_Membership_Log\_\_c object
- Filtering by `Updated_At__c` or `Message__c`
- Verifying membership through CollaborationGroupMember records

---

## 🚀 Future Enhancements

|       **Feature**       |                                 **Notes**                                  |
| :---------------------: | :------------------------------------------------------------------------: |
| Dynamic Group Selection | Use custom metadata or Flow input variables instead of hardcoding Group ID |
|     Error Handling      |       Add fault paths to log or notify errors during record creation       |
|   Notification Email    |            Optionally email a summary of actions after each run            |
