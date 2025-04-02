# KeepAlive Sessions in Salesforce Experience Cloud

This page documents how we implemented a session keep-alive strategy for our Salesforce Experience Cloud site, and how to maintain it over time.

---

## Why We Did This

By default, users are logged out of our Experience Cloud site after 24 hours of inactivity. We wanted to improve the user experience by reducing the frequency of session timeouts, especially for members who leave a tab open for long periods.

---

## How It Works

We created a lightweight **Aura component** called `keepAlive`, which silently pings a no-op Apex method (`KeepAliveController.ping()`) every 10 minutes. This keeps the user session active as long as the tab remains open.

- **Component Name:** `keepAlive`
- **Apex Controller:** `KeepAliveController`
- **Ping Interval:** 10 minutes
- **Location:** The component is added to the site's shared header layout to ensure it runs on all pages.

---

## How We Built It

1. **Created Apex Class: `KeepAliveController`**
    - Public, static, and marked `@AuraEnabled`
    - Contains an empty `ping()` method

2. **Created Aura Component: `keepAlive`**
    - On page load, starts a JS `setInterval` timer that calls `KeepAliveController.ping()` every 10 minutes
    - Logs results to the browser console for debugging

3. **Added the component to the site header in Experience Builder**
    - Ensures it loads on every page without duplicating it per page

4. **Tested in browser using DevTools (Console + Network tabs)**

---

## Maintaining Apex Class Access

If new user profiles are added, or users report seeing this error in the Development Tools Console:

> `"You do not have access to the Apex class named 'KeepAliveController'"`

…then you need to **grant access to the Apex class**. Here's how:

### 🔧 Steps to Update Profile > Apex Class Access

1. Go to **Setup > Profiles**
2. Find and click on the profile name (e.g. `SM Community Plus Member`)
3. Scroll down to **Apex Class Access**
4. Click **Edit**
5. Move `KeepAliveController` from the Available list to the Enabled list
6. Click **Save**

---

## Verifying It's Working

1. Open the browser's **DevTools > Console**
2. Look for log messages like: `[KeepAlive] Pinging server to keep session alive… [KeepAlive] Ping response: SUCCESS`
3. Visit **Setup > Session Management** to view real-time session activity

---

## Contact

If you're troubleshooting this feature or extending it, contact [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org) or check the source code in our GitHub repository.
