# How to Add Federation ID Update Logs to the App Launcher

After creating a custom object for logging Federation ID updates, you may want to easily find and search these log records through the Salesforce App Launcher.

By default, custom objects don't appear in the App Launcher until you create a **Custom Tab**.

This guide walks you through how to make your Federation ID Update Logs searchable and accessible.

---

## 🛠 Step 1: Create a Custom Tab

1. Go to **Setup** (Gear Icon → Setup).
2. In the Quick Find box, search for **Tabs**.
3. Click on **Tabs** under User Interface.
4. Scroll down to the **Custom Object Tabs** section.
5. Click **New**.

---

## 🧩 Step 2: Configure the New Tab

- **Object**: Select `Federation ID Update Log` (or the name you used).
- **Tab Style**: Pick any icon (for example, a document or checkmark).
- **Tab Label**: It will default to the object name; you can customize if you like.

✅ Leave all other defaults.

Click **Next**.

---

## 🧩 Step 3: Set Tab Visibility

- **Set Tab Visibility** for profiles:
    - Typically, choose **Default On** for Admin profiles.
    - Or customize based on who should see the logs.

Click **Next**.

---

## 🧩 Step 4: Add to Apps (Optional)

Salesforce will prompt you to add this tab to various Apps (like "Sales" or "Service Console").  
You can skip this for now unless you specifically want it showing inside a particular app.

Click **Save**.

---

## 🔍 Step 5: Search in App Launcher

Now that the Tab is created:

1. Go to the **App Launcher** (grid icon top left).
2. **Search for** `Federation ID Update Logs`.
3. Click on it.

✅ You can now view, search, and manage your log records easily.

---

## 📋 Summary

| Step | Action                                          |
| :--- | :---------------------------------------------- |
| 1    | Setup → Tabs → New Custom Object Tab            |
| 2    | Select `Federation ID Update Log` as the object |
| 3    | Pick a Tab Style and configure visibility       |
| 4    | Save and deploy                                 |
| 5    | Search for your logs in the App Launcher        |

---

> ✨ _Once added, you can also create List Views, Filters, and Reports based on your Federation ID Update Logs._
