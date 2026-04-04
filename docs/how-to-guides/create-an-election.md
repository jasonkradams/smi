# Create an Election

This guide walks through creating and distributing a Spokane Mountaineers secret-ballot election using the Election Manager web app.

You will need:

- Access to the [Election Manager](https://script.google.com/a/macros/spokanemountaineers.org/s/AKfycbxKvex6OsXOa-QdXvNpJYn5KfjTdHVb1t6RB3FTieeOlbS5JlMcXxULkWM95hl6EkAB/exec) (requires a spokanemountaineers.org Google account)
- The list of candidate names for each position on the ballot
- A list of member email addresses to receive ballots

---

## Step 1 — Open the Election Manager

Open the [Election Manager](https://script.google.com/a/macros/spokanemountaineers.org/s/AKfycbxKvex6OsXOa-QdXvNpJYn5KfjTdHVb1t6RB3FTieeOlbS5JlMcXxULkWM95hl6EkAB/exec). You will see two options:

- **Create New Election** — set up a new ballot from scratch
- **Manage Existing Election** — load a previously created election

Click **Create New Election**.

---

## Step 2 — Fill in election details

Four fields appear at the top of the form:

**Election Title** — Enter a descriptive name, such as `2026 Annual Officers Election`. This becomes the name of the Google Form and the response spreadsheet.

**Start Date** — The date voting opens. Once this date is reached, the election locks and most fields can no longer be edited.

**Close Date** — The last day members can submit a vote.

**Save To Folder** — Choose the year folder where the election files will be stored (e.g., `2026`). If the year folder does not exist yet, select **+ Create New Folder...** and type the folder name.

---

## Step 3 — Build the ballot

The ballot section lists five preset positions. Check the box next to each position that appears on this election's ballot:

- President (members choose one)
- Vice President (members choose one)
- Treasurer (members choose one)
- Secretary (members choose one)
- Board of Directors (members may choose multiple)

When you check a position, a candidate entry field appears beneath it. Type each candidate's name and press **Enter** (or comma) to add them. Each name appears as a tag — click the **×** on a tag to remove it. You can also paste a comma-separated list of names all at once.

Candidate names are automatically formatted in title case, and duplicates are removed.

> A candidate may only appear under one position. If the same name is entered under two different positions, the form will alert you before saving.

---

## Step 4 — Add the member email list

Paste all member email addresses into the **Member Email List** field, one per line. The app accepts a plain list, cleans up duplicates, and flags any addresses that look malformed.

The counter above the field shows how many valid addresses are loaded.

---

## Step 5 — Create the election

Click **Initialize Election & Create Form**.

The app will:

1. Create a Google Form with your ballot questions
2. Create a Google Spreadsheet to store responses and track voting tokens
3. Move both files into the year folder you selected

When it finishes, a **Send Voting Tokens** card appears below the form.

---

## Step 6 — Send voting tokens

The Send Voting Tokens card shows the election name and links to the ballot form and response spreadsheet. Review these links to confirm everything looks correct before sending.

Click **Send Tokens via Email**.

Each member on the list receives a personalized email with a unique voting link. The link pre-fills their token into the ballot form — they do not need to copy or type anything. Once a token is used, it cannot be used again.

> Sending tokens to a large list may take a minute or two. Wait for the confirmation message before closing the page.

---

## After the election closes

Once the close date has passed, the election is permanently read-only. Vote results are in the **Vote Results** tab of the response spreadsheet. Each row is an anonymized ballot — member identities are not stored alongside their votes.

---

## Editing an election before voting opens

If you need to correct the ballot or update the member list before the start date, open the [Election Manager](https://script.google.com/a/macros/spokanemountaineers.org/s/AKfycbxKvex6OsXOa-QdXvNpJYn5KfjTdHVb1t6RB3FTieeOlbS5JlMcXxULkWM95hl6EkAB/exec), click **Manage Existing Election**, select the election from the dropdown, and click **Load Election**. Make your changes and use **Save Ballot Changes** or **Save Updated Email List** as appropriate.

Once the start date is reached, fields are locked. A yellow banner will appear if you need to make a correction to a live election — check the **Locked** toggle and confirm the dialog to unlock it temporarily. An audit notification will be sent to the tech team when an in-progress election is unlocked.

---

## Need help?

Contact the tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
