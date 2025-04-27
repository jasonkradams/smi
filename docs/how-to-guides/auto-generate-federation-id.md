# Auto-Generate Federation ID for New User Accounts

When creating a new user account in Salesforce, we automatically generate a **Federation ID** based on the user's provided email address.  
This Federation ID is critical because it must match the **account ID** that will later be created in **Google Workspace** for that user.

> 🚨 Note: Users **will not have login access** to their Google Workspace accounts. However, their Federation IDs must match exactly for SAML authentication and directory synchronization.

---

## 🛠 How It Works

When a new user is added via the New User Account Creation Flow:

- A formula automatically generates the Federation ID.
- The Federation ID:
  - Preserves the local part of their email (before the `@` symbol),
  - Appends a shortened version of their original email domain,
  - Ends with **@spokanemountaineers.org**.

This approach helps avoid conflicts if multiple users share the same username but have different domains (for example, `jane.doe@gmail.com` and `jane.doe@aol.com`).

---

## 🧩 Formula Details

The Salesforce Flow ([Create New Member User](https://spokanemountaineers.lightning.force.com/builder_platform_interaction/flowBuilder.app?flowId=301Um00000iuPwuIAE)) uses `formula_federation_id` to generate the Federation ID.:

```plaintext
LOWER(
  LEFT({!Get_Contact.Email}, FIND("@", {!Get_Contact.Email}) - 1)
  & "_"
  & LEFT(
      MID({!Get_Contact.Email}, FIND("@", {!Get_Contact.Email}) + 1, LEN({!Get_Contact.Email})),
      FIND(".", MID({!Get_Contact.Email}, FIND("@", {!Get_Contact.Email}) + 1, LEN({!Get_Contact.Email}))) - 1
    )
  & "@spokanemountaineers.org"
)
```

### ✏️ What it does:
- `LEFT(... FIND("@") - 1)` — Grabs the part before the `@`.
- `MID(... FIND("@") + 1)` — Grabs the domain after the `@`.
- `LEFT(... FIND("."))` — Shortens the domain to just the first word (e.g., `gmail`, `aol`).
- `LOWER(...)` — Ensures everything is lowercase for consistency.
- Adds `_domainname` to avoid duplicate Federation IDs.
- Appends `@spokanemountaineers.org` at the end.

---

## 📚 Example Scenarios

| User Input Email                      | Generated Federation ID                                   |
| ------------------------------------- | --------------------------------------------------------- |
| `jane.doe@gmail.com`                  | `jane.doe_gmail@spokanemountaineers.org`                  |
| `jane.doe@aol.com`                    | `jane.doe_aol@spokanemountaineers.org`                    |
| `john.smith@outlook.com`              | `john.smith_outlook@spokanemountaineers.org`              |
| `chris.brown@spokanemountaineers.org` | `chris.brown_spokanemountaineers@spokanemountaineers.org` |

---

## 🔥 Why This Matters

- **Uniqueness**: Prevents collisions between users who have the same username across different email domains.
- **Compliance**: Ensures that Salesforce Federation IDs match the IDs in Google Workspace.
- **Automation**: Reduces manual work when creating and managing new user accounts.

---

## ✅ Summary

- New user Federation IDs are generated automatically.
- They follow a standard naming pattern to avoid conflicts.
- These IDs are used to create corresponding Google Workspace accounts (without granting user access).
- No manual Federation ID entry is needed for new accounts!

---

> ✨ *If you encounter any issues or need to update the formula, please open a GitHub Issue on the [Spokane Mountaineers Docs Repository](https://github.com/jasonkradams/smi/issues/new).*
