# Auto-Generate Federation ID for New User Accounts (Updated)

> _⚠️ Note: Do not assume all usernames have .smi. See logic below._

When creating a new user account in Salesforce, we automatically generate a **Federation ID** based on the user's provided **Username** field.

This Federation ID must match the account ID format expected by our future Google Workspace system.

> 🚨 Important: Users **do not** have direct login access to Google Workspace, but Federation IDs must match exactly for SSO and directory synchronization.

---

## 🛠️ How It Works (Updated)

When a new user is added:

- The **Username** is used as the base, not Email.
- If the Username ends with `.smi`, that part is removed.
- The `@` symbol is replaced with an `_`.
- The final Federation ID is appended with `@spokanemountaineers.org`.

This ensures **uniqueness**, **compatibility**, and **consistency** across the system.

---

## 🧩 Updated Formula Details

**Salesforce Flow Formula (Text):**

```plaintext
SUBSTITUTE(
  IF(
    CONTAINS({!User.Username}, ".smi"),
    LEFT({!User.Username}, FIND(".smi", {!User.Username}) - 1),
    {!User.Username}
  ),
  "@",
  "_"
) & "@spokanemountaineers.org"
```

---

### ✏️ What this formula does:

- **If** the Username contains `.smi`, **remove** it.
- **If not**, use the Username as-is.
- **Replace** the `@` symbol with `_`.
- **Append** `@spokanemountaineers.org` to the end.

✅ This handles users whether `.smi` is present or missing, avoiding duplicates and errors.

---

## 📚 Example Outputs

| Username                         | Resulting Federation ID                                  |
| :------------------------------- | :------------------------------------------------------- |
| `_a.first.last@gmail.com.smi`    | `_a.first.last_gmail.com@spokanemountaineers.org`        |
| `first.list+example@example.com` | `first.list+example_example.com@spokanemountaineers.org` |
| `jane.doe@yahoo.com.smi`         | `jane.doe_yahoo.com@spokanemountaineers.org`             |
| `mark.smith@outlook.com`         | `mark.smith_outlook.com@spokanemountaineers.org`         |

---

## 🔥 Why This Matters

- **Uniqueness**: Federation IDs based on Username are globally unique within Salesforce.
- **Consistency**: Usernames that vary (with or without `.smi`) are handled properly.
- **Compliance**: Matches Google Workspace expectations for user mapping.
- **Automation**: No manual Federation ID entry needed.

---

## 📋 Summary

- Federation IDs are now based on **Username**, not Email.
- `.smi` suffixes are removed if present.
- `@` symbols are replaced with `_`.
- Appends `@spokanemountaineers.org`.
- This protects against duplicates and Salesforce field integrity errors.

---

> ✨ _If future usernames or rules change, this formula should be reviewed and updated accordingly._
