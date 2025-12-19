# Batch Update Federation IDs for Existing Users

This guide walks through how to batch-update Federation IDs for existing Salesforce users and create a simple audit log of updates.

> 🚨 Federation IDs must match the account ID format expected by our Google Workspace system.  
> New users are handled automatically, but existing users must be updated manually one time.

---

## 🛠 Overview

We created a Flow that:

- Finds users missing a Federation ID,
- Calculates a correct Federation ID based on their email,
- Updates the User record,
- Logs the change to a custom "Federation ID Update Log" object,
- Allows easy review with a List View.

---

## 🧩 Step 1: Create the Federation ID Update Log Object

1. Go to **Setup** → **Object Manager** → **Create** → **Custom Object**.
2. Fill out:
    - **Label**: `Federation ID Update Log`
    - **Plural Label**: `Federation ID Update Logs`
    - **Object Name**: `FederationIDUpdateLog`
    - **Record Name**: Auto-Number, format `FID-{0000}`
    - **Description**: `Log of Federation ID updates performed by automated flows.`

3. Check these options:
    - ✅ Allow Reports
    - ❌ Allow Activities (optional)
    - ✅ Deployment Status: Deployed

4. Save.

---

### Add Custom Fields to the Object:

| Field Label       | Field Type | API Name             | Notes                    |
| :---------------- | :--------- | :------------------- | :----------------------- |
| User ID           | Text (255) | `UserId__c`          | Salesforce User Id       |
| Old Federation ID | Text (255) | `OldFederationId__c` | Previous value           |
| New Federation ID | Text (255) | `NewFederationId__c` | New value                |
| Email             | Email      | `Email__c`           | User’s email address     |
| Updated At        | Date/Time  | `UpdatedAt__c`       | When the update happened |

---

## 🛠 Step 2: Create the Batch Update Flow

1. Go to **Setup** → **Flows** → **New Flow**.
2. Type: **Autolaunched Flow** (no trigger).

---

### Build the Flow:

#### 1. Get Records: Find Users

- **Object**: `User`
- **Conditions**:
    - `FederationId IS NULL`
    - `Profile.Name CONTAINS 'Experience'`
- Store: **All Records**

---

#### 2. Loop Through Users

- Add a **Loop** over the collection of users without Federation IDs.

Inside the Loop:

---

#### 3. Create Assignment: Calculate New Federation ID

Create a Formula Resource:

```plaintext
LOWER(
  LEFT({!LoopedUser.Email}, FIND("@", {!LoopedUser.Email}) - 1)
  & "_"
  & LEFT(
      MID({!LoopedUser.Email}, FIND("@", {!LoopedUser.Email}) + 1, LEN({!LoopedUser.Email})),
      FIND(".", MID({!LoopedUser.Email}, FIND("@", {!LoopedUser.Email}) + 1, LEN({!LoopedUser.Email}))) - 1
    )
  & "@spokanemountaineers.org"
)
```

Assign this value to the **FederationId** field for the current User.

---

#### 4. Create Record: Log the Update

- Create a new record in `Federation ID Update Log`:
    - **UserId\_\_c** = `{!LoopedUser.Id}`
    - **OldFederationId\_\_c** = `{!LoopedUser.FederationId}`
    - **NewFederationId\_\_c** = Calculated Federation ID
    - **Email\_\_c** = `{!LoopedUser.Email}`
    - **UpdatedAt\_\_c** = `Now()`

---

#### 5. After Loop: Update Records

- Use **Update Records** to update all modified users at once (bulk safe).

---

## 🛠 Step 3: Schedule the Flow

1. In the Flow Settings, click **Set a Schedule**.
2. Set it to run **once** immediately, or at a quiet time (overnight).

✅ This will batch process all users missing Federation IDs.

---

## 🔎 Step 4: Add a List View for Log Visibility

1. Go to **App Launcher** → Search **Federation ID Update Logs**.
2. If needed, **Create a Tab** in Setup → Tabs → New Custom Object Tab.
3. On the "Federation ID Update Logs" screen:
    - Click the **Gear Icon** ⚙️.
    - Click **New List View**.
4. Name it something like:
    - `All Logs`
    - or `Recent Federation Updates`
5. Set visibility to yourself or your admin group.
6. Customize Columns:
    - Add: `Email`, `Old Federation ID`, `New Federation ID`, `Updated At`.
7. Save.

✅ Now you can monitor every Federation ID update that the batch flow processed.

---

## 📚 Summary

- Existing users are updated automatically using a Scheduled Flow.
- Updates are logged into a custom object for easy auditing.
- A List View provides real-time visibility into which users were updated.
- This ensures that all Salesforce Federation IDs match our future Google Workspace accounts exactly.

---

> ✨ _If you need to re-run the batch update in the future, simply re-schedule or manually trigger the Flow._
