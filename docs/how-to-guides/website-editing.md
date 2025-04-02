# Editing the Spokane Mountaineers Website

This guide walks through how to update content on the Spokane Mountaineers public website, including page editing, image management, and maintaining our Experience Cloud infrastructure.

---

## 🔐 Admin Access

To access administrative tools, log in at:

👉 [https://spokanemountaineers.my.salesforce.com](https://spokanemountaineers.my.salesforce.com)

If you need credentials or access permissions, contact the tech team.

---

## 🌐 Public Website

The public-facing site is hosted at:

👉 [https://www.spokanemountaineers.org](https://www.spokanemountaineers.org)

It is powered by Salesforce **Experience Cloud** (Aura framework) and managed using Experience Builder and Salesforce Setup.

---

## 🧭 Helpful Salesforce Links

Here are commonly used Salesforce admin tools:

| Name                  | Link                                                                 |
|-----------------------|----------------------------------------------------------------------|
| Setup Home            | [Setup](https://spokanemountaineers.lightning.force.com/lightning/setup/SetupOneHome/home) |
| Digital Experiences   | [Experience Builder](https://spokanemountaineers.lightning.force.com/lightning/cms/home) |
| User Management       | [Users](https://spokanemountaineers.lightning.force.com/lightning/setup/ManageUsers/home) |

Bookmark these for easy access when managing site content or user permissions.

---

## ✏️ Editing Pages in Experience Builder

1. Navigate to [Digital Experiences](https://spokanemountaineers.lightning.force.com/lightning/cms/home).
2. Click **Builder** next to the `Spokane Mountaineers` site.
3. In Builder, you can:
   - Click on page sections to edit content
   - Add or remove components from the layout
   - Update navigation and metadata

---

## 🖼 Adding or Replacing Images

1. In Builder, select the image component you want to change.
2. Click **Upload Image** or choose from existing **Site Assets**.
3. Use optimized images in `.jpg`, `.png`, or `.webp` format, ideally under 1MB.

---

## ✅ Publishing Changes

After making edits:

1. Click **Publish** in the top-right corner of Experience Builder.
2. Choose **Publish to All** to make the changes live.
3. Verify by visiting [spokanemountaineers.org](https://www.spokanemountaineers.org).

You can also use the **Preview** button to test changes before publishing.

---

## 🛠 Advanced Editing (Admins Only)

For more complex changes, like updating custom Aura components:

- Use **VS Code with the Salesforce CLI**
- Deploy changes via `sf project deploy start`
- Use **Apex**, **Lightning components**, and **custom objects** responsibly

If you're not familiar with these tools, contact a dev/tech lead before making changes.

---

## 📝 Related Docs

- [KeepAlive Sessions](keepalive-sessions.md)
- [Updating Member Profiles](user-profile-management.md)

---

## Contributing

This site is maintained by volunteers. If you'd like to contribute documentation or suggest edits:

- Fork or clone the repository: [github.com/jasonkradams/smi](https://github.com/jasonkradams/smi)
- Make changes in Markdown
- Submit a pull request

If you're unsure how to get started, contact the tech team or open an issue in the repository.
