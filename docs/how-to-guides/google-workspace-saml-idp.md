# 🛡️ Using Google Workspace as a SAML Identity Provider Only

This document explains how to configure Google Workspace so that it acts **only** as a **SAML Identity Provider (IdP)** for Salesforce logins — without giving users Gmail, Drive, or other Google Apps access.

The goal is to make login easy for members while keeping Google Workspace invisible to them.

---

## 🎯 Goal

- Authenticate members into Salesforce via **SAML Single Sign-On**.
- Prevent members from accessing Gmail, Drive, Calendar, etc.
- Avoid sending unnecessary account emails to members.
- Keep Google Workspace "silent" — used only for authentication.

---

## ✅ Steps to Configure

### 1. Create Bare-Bones Google Accounts

- In **Google Admin Console**:
  - Go to **Directory → Users → Add new user**.
  - When adding a user, **uncheck** "Send login info to this email address" to avoid sending a welcome email.

Alternatively, when bulk importing users via CSV:
- Do not specify notification email fields.
- Upload users without triggering email alerts.

> ⚡ Members will not be notified or required to interact with Google directly.

---

### 2. Restrict Access to Google Apps

Set up an Organizational Unit (OU) to manage app access:

- **Create a new OU** called `IdP Only Users`.
- Move all SAML-only users into this OU.
- In **Apps > Google Workspace > Settings for Org Units**:
  - **Disable**:
    - Gmail
    - Google Drive
    - Google Calendar
    - Google Meet
    - Google Chat
    - Any other unneeded Google Apps
- **Leave enabled**:
  - Google Identity Services (required for SAML authentication)

> ✅ This ensures users cannot use Google services — only authentication via SAML.

---

### 3. Manage Salesforce User Records

- Maintain standard Salesforce users (create, deactivate as needed).
- Ensure each Salesforce User's **Federation ID** matches their Google Workspace **Primary Email**.
- Continue managing user permissions (Profiles, Roles, Permission Sets) within Salesforce.

---

## 🔥 How Login Works for Members

| Step | What Happens |
|:---|:---|
| Member visits Salesforce login page | |
| Member clicks "Login with SSO" | |
| Google Workspace authenticates identity (behind the scenes) | |
| Member is redirected into Salesforce | |

> 🧠 The member never directly logs into Google Workspace, sees a Gmail inbox, or manages a Google password.

---

## 📋 Key Admin Reminders

- When a member leaves, **deactivate their Salesforce user** and optionally **suspend their Google Workspace account**.
- If your organization grows beyond the free Google tier limits (currently ~300 users), monitor your Workspace license usage.
- Keep a consistent naming convention for user emails, e.g., `firstname.lastname@yourorg.org`.
- Regularly audit your OUs to ensure proper separation of "IdP Only" users.

---

## 🚀 Optional Future Enhancements

- Automate user creation in Google Workspace with scripts or APIs.
- Use Data Loader in Salesforce for batch updates to Federation IDs.
- Implement monitoring to ensure consistency between Google and Salesforce user directories.

---

## 🧠 Summary

| Area | Responsibility |
|:---|:---|
| Google Workspace | Authentication Only (no Apps access) |
| Salesforce | User Management, Authorization, Permissions |
| Member Experience | Simple, no new accounts to manage |

By following this setup, your members will enjoy a seamless, simplified login experience, and your admin team will maintain full control over access without additional complexity.

---
