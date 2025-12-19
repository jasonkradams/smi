# Delete Federation ID From Users

This document explains the **Delete Federation ID From 25 Users** flow used for mass resetting user Federation IDs.

This flow was critical when reconfiguring the Federation ID generation logic across all users, and was used to **bulk clear existing Federation IDs** before rebuilding them properly.

---

## 🛠 Flow Information

- **Flow Name**: `Delete Federation ID From 25 Users`
- **Flow URL**: [Delete Federation ID From 25 Users](https://spokanemountaineers.lightning.force.com/lightning/setup/Flows/page?address=%2F300Um00000koZJRIA2%3FretUrl%3D%2Flightning%2Fsetup%2FFlows%2Fhome)
- **Flow Type**: Scheduled-Triggered Flow
- **Schedule**: Daily (but primarily run manually during reset operations)

---

## 🖼 Flow Diagram: Delete Federation ID From 25 Users

```plaintext
(Start: Scheduled Daily or Manual Run)
       ↓
[Get Records: Pull Users Without Federation ID (limit 25)]
       ↓
[Decision: Records Present?]
    ┌───────────────┐                      ┌───────────────────────────────┐
    │ Has Records   │                      │ No Records                    │
    │ (Users Found) │                      │ (No Users to Clear)            │
    └──────┬────────┘                      └─────────────┬─────────────────┘
           ↓                                             ↓
[Loop: Remove Federation ID]                      [Create Log Record: No Users]
    ↓
[Assignment: Create Log Record for Each User]
    ↓
[Assignment: Assign Empty Federation ID to Each User]
    ↓
(After Last Loop)
    ↓
[Update Records: Bulk Update Users (FederationId cleared)]
    ↓
[Create Records: Bulk Create Log Records]
    ↓
(End)
```

---

## 📋 Purpose

- Quickly **clear (null out)** the `FederationId` field for active User records.
- Remove incorrect or duplicate Federation IDs when the original creation formula was found to be flawed.
- Ensure that all Users could be assigned **new, correct Federation IDs** afterward.

---

## 🔎 How It Works

1. **Pull Users Without Federation ID**:
    - Get up to 25 Users at a time who still have a populated FederationId.
    - Filters out integration users, inactive users, and others not needing modification.

2. **Decision: Records Present?**:
    - If users are found → Continue.
    - If no users are found → Create a single Log entry and End.

3. **For Each User**:
    - **Create a Log Record** capturing the removal action.
    - **Assign an empty value to FederationId** (effectively nulling it).
    - Add the User and Log Record to their respective Collections.

4. **After Loop**:
    - **Update User Records** in bulk (nulling Federation IDs).
    - **Create Log Records** in bulk for auditing.

5. **End**.

---

## 🛠 Manual Running

- This flow was **manually triggered** multiple times (about 60 clicks).
- Each run cleared Federation IDs for up to 25 users.
- Repeatedly running the flow cleared **all users** in manageable, batch-safe steps.

> 🛠 **Note**: This method is "quick and dirty" — not perfect — but effective for a one-time reset.

---

## 🔍 Associated Logs

Logs are created under the custom app:

- **App Name**: `Remove Federation ID Logs`
- Accessible via the App Launcher by searching for `Remove Federation ID Logs`.
- These records contain:
    - Which User was cleared.
    - When the clearing action happened.
    - Original Federation ID values.

✅ These logs provide full auditability of all Federation ID resets performed.

---

## 📚 Lessons Learned

- Always ensure Federation ID formulas are stable before mass applying them.
- Having a quick "clear/reset" tool ready can save significant time during cleanup efforts.
- Batching 25 records at a time avoids DML governor limits and memory overages.

---

> ✨ _This flow is retained for future administrative use if a Federation ID reset is ever needed again._
