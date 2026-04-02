# Send as Your Spokane Mountaineers Email from Hotmail

This guide walks Spokane Mountaineers leadership through configuring their personal Hotmail (Outlook.com) account to send and reply to email using their official `@spokanemountaineers.org` address — routed through Google's own mail servers for reliable delivery, with sent messages saved back to Gmail.

This is the first in a series of guides covering this setup across different personal email clients.

---

## Overview

Your official Spokane Mountaineers email address is hosted on Google Workspace (Gmail). Rather than switching between two inboxes, you can connect your organization account to Hotmail so that:

- Outgoing mail is delivered through Google's servers (not Microsoft's), avoiding "on behalf of" headers
- Sent messages are saved back to Gmail's Sent folder via IMAP, keeping Gmail the authoritative record

This requires a one-time setup that combines IMAP (for reading and writing Gmail folders) with SMTP (for sending through Gmail's servers).

---

## Before You Begin

You will need:

- Your `@spokanemountaineers.org` email address and password
- Access to your Hotmail / Outlook.com inbox
- A few minutes to complete the one-time setup

---

## Step 1: Generate a Gmail App Password

Because your organization email is a Google Workspace account, you'll use an **App Password** to authorize Hotmail to access your account. One App Password covers both IMAP and SMTP — you only need to create it once.

1. Open a browser and go to [myaccount.google.com](https://myaccount.google.com).
2. Sign in with your `@spokanemountaineers.org` account if prompted.
3. In the left sidebar, click **Security & sign in**.
4. Scroll to the **"How you sign in to Google"** section.
5. Click **2-Step Verification**.
    - If 2-Step Verification is not yet enabled, you must enable it before App Passwords become available. Follow the on-screen prompts and return here when done.
6. Scroll to the bottom of the 2-Step Verification page and click **App passwords**.
7. In the **"App name"** field, type something descriptive, such as `Hotmail`.
8. Click **Create**.
9. Google will display a 16-character password. **Copy this password now** — you will not be able to view it again after closing the dialog.

!!! note
Keep this App Password private. It grants access to send and read mail as your organization address without your main password.

---

## Step 2: Add Your Organization Account to Hotmail

Outlook.com connects to your Gmail account using both IMAP (to sync folders and save sent mail) and SMTP (to send through Google's servers). You configure them together in one step.

1. Go to [outlook.live.com](https://outlook.live.com) and sign in to your personal Hotmail account.
2. Click the **Settings** gear icon in the upper-right corner.
3. Click **View all Outlook settings** at the bottom of the settings panel.
4. Navigate to **Mail → Sync email**.
5. Under **Connected accounts**, click **Other email accounts**.
6. Fill in the form as follows:

    | Field         | Value                                              |
    | ------------- | -------------------------------------------------- |
    | Display name  | Your name (as you want it to appear to recipients) |
    | Email address | Your `@spokanemountaineers.org` address            |
    | Password      | The 16-character App Password from Step 1          |

7. Expand **Advanced options** (if shown) and confirm or enter the following server settings:

    | Setting         | Value            |
    | --------------- | ---------------- |
    | IMAP server     | `imap.gmail.com` |
    | IMAP port       | `993`            |
    | IMAP encryption | SSL              |
    | SMTP server     | `smtp.gmail.com` |
    | SMTP port       | `587`            |
    | SMTP encryption | TLS              |

8. Click **OK** to save.

Outlook.com will verify the credentials and begin syncing. If the connection is rejected, double-check that you copied the App Password correctly (no spaces).

!!! note
Outlook.com may auto-detect the correct server settings after you enter the email address and password. If it does, you can skip the manual server fields and proceed directly to saving.

---

## Step 3: Verify Sent Mail Lands in Gmail

After setup, send a test message using your organization address and confirm it appears in Gmail's Sent folder:

1. In Outlook.com, click **New message**.
2. In the **From** field (click it to reveal the dropdown), select your `@spokanemountaineers.org` address.
3. Address the message to yourself and send it.
4. Open [Gmail](https://mail.google.com) in another tab and check the **Sent** folder — the message should appear there within a minute or two.

If it does not appear in Gmail's Sent folder, see the troubleshooting section below.

---

## Step 4: Set a Default From Address (Optional)

If most of your outgoing email should come from your organization address, you can set it as the default:

1. Return to **Settings → Mail → Sync email**.
2. Under **Default From address**, use the dropdown to select your `@spokanemountaineers.org` address.
3. Click **Save**.

New messages and replies will now default to your organization address. You can still switch to your personal Hotmail address on a per-message basis using the **From** dropdown when composing.

---

## Troubleshooting

**"Something went wrong" when adding the account**
: Make sure 2-Step Verification is enabled on your Google account before generating an App Password. If you enabled it just now, try generating a new App Password.

**App passwords option is not visible**
: This option only appears when 2-Step Verification is active. If your organization's Google Workspace admin has restricted App Password access, contact [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) for help.

**Sent mail does not appear in Gmail's Sent folder**
: Confirm that the account was added with the IMAP settings in Step 2, not just the email address and password alone. If Outlook.com auto-detected settings and skipped IMAP, remove the connected account and re-add it using the manual server fields.

**Recipients see "via outlook.com" in the From address**
: This should not happen when the account is connected via SMTP as described above. If you see it, verify that Outlook.com is using Gmail's SMTP server (`smtp.gmail.com`) and not its own. Remove and re-add the account if needed.

**Sent mail appears in Hotmail's Sent folder but not Gmail's**
: This indicates Outlook.com connected via SMTP only, without the IMAP component. Remove the connected account, re-add it, and make sure to enter the IMAP server settings (`imap.gmail.com`, port `993`, SSL) during setup.

---

## Related Guides

More guides in this series will cover setup for other common personal email clients, including Apple Mail, Live.com, and others. Check the [How-To Guides index](index.md) as they are added.
