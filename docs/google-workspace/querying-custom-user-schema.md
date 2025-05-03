# Querying Custom Schema: Mountaineers.PublicEmail

This document explains how to access and query the custom schema field `Mountaineers.PublicEmail` that is populated by the [user sync](../automation/user-sync-google-workspace/google-app-script/appsscript.json) script.

---

## 🧩 Schema Definition

| Schema Name    | Field Name    | Type   | Description                           |
| -------------- | ------------- | ------ | ------------------------------------- |
| `Mountaineers` | `PublicEmail` | String | Public-facing email for mailing lists |

This field is stored under the `customSchemas` object in each user's Google Workspace profile. Example JSON structure:

```json
"customSchemas": {
  "Mountaineers": {
    "PublicEmail": "public-facing@example.com"
  }
}
```

---

## 🔍 Query via Admin SDK

Use the Directory API `users.list` endpoint with `projection=full`:

```http
GET https://admin.googleapis.com/admin/directory/v1/users?customer=my_customer&orgUnitPath=/IdP%20Users%20Only&projection=full
```

Parse each user's schema:

```json
user.customSchemas?.Mountaineers?.PublicEmail
```

Reference: [Admin SDK Directory API - Users: list](https://developers.google.com/admin-sdk/directory/reference/rest/v1/users/list)

---

## 🧰 Query via GAM CLI

### Show for a single user:

```sh
gam users show <user@example.com> fields customSchemas
```

### Export for all users in OU:

```sh
gam print users query "orgUnitPath='/IdP Users Only'" \
  fields primaryEmail,customSchemas.Mountaineers.PublicEmail \
  > mountaineers-emails.csv
```

---

This enables easy generation of mailing lists based on public-facing emails independent of Google usernames.
