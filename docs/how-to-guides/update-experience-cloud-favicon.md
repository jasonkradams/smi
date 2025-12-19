# Updating the Favicon for an Experience Cloud Site

This guide shows how to update the favicon (`favicon.ico`) for a Salesforce Experience Cloud site when the site template does not support favicon branding through the standard **Branding** settings.

## Step 1: Upload the Favicon as a Static Resource

1. Navigate to **Setup** → **Static Resources**.
2. Click **New**.
3. Fill out the form:
    - **Name**: `favicon_ico`
    - **File**: Upload your `favicon.ico` file
    - **Cache Control**: `Public`
4. Save the static resource.

> 💡 Best format is a `.ico` file at 16x16 or 32x32 pixels.

## Step 2: Add a Reference to the Favicon in the Site Head

1. Go to **Setup** → **Digital Experiences** → **All Sites**.
2. Click **Builder** next to your site.
3. In **Experience Builder**:
    - Click the **gear icon (⚙️)** in the top right.
    - Go to **Advanced** → **Edit Head Markup**.
4. Add the following HTML:

    ```html
    <link rel="icon" type="image/x-icon" href="/resource/favicon_ico" />
    ```

    Replace FaviconICO with the name you gave your static resource if it differs.

5. Click Done and Publish your site.

## Troubleshooting

- If the new favicon doesn't show up immediately:
    - Open the site in an incognito window.
    - Clear your browser cache.
    - Ensure the static resource is publicly accessible.

---

## ✅ Example

If your favicon file is named favicon.ico and uploaded as a static resource named FaviconICO, the browser will now use:

```html
<link rel="icon" type="image/x-icon" href="/resource/FaviconICO" />
```

---

## 🔁 Why This is Needed

Some Experience Cloud templates (e.g., Help Center, Customer Service) do not offer a "Branding" section in the settings UI. In those cases, the favicon must be manually added via the \<head> section.
