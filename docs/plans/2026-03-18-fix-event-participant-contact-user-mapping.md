# Fix Event Participant Contact→User Mapping — Investigation & Fix Plan

## Overview

Some participants in the `eventParticipantRelatedList` component display as grey (non-clickable) names instead of profile links. The component uses `Contact.User_Lookup__c` to resolve a Contact to a User for the profile link. When `User_Lookup__c` is null, `hasUser = false` and the name renders as plain grey text instead of a link.

**Confirmed Example**:

- Contact: Dillon Oergel (`003Um00001SEmTxIAL`), `Email = doergel1@gmail.com`
- User: `005Um00000B6gflIAB`, `Email = doergel1@gmail.com`, `Username = doergel1@gmail.com.smi`
- `Contact.User_Lookup__c = null` — yet a perfectly matching User exists

---

## Root Cause

The `Contact.User_Lookup__c` field is **never automatically populated**. The sync methods (`syncContactToUser`, `bulkSyncContactsToUsers`) exist in `EventParticipantRedirectHelper.cls` but are never called automatically — they must be triggered explicitly. No Flow or trigger populates this field on Contact create/update.

When `getEventParticipants` runs, it reads `Contact__r.User_Lookup__c` directly. If that field is null, `hasUser = false` and no profile link is rendered — even when a matching User exists.

### Matching Logic (in `syncContactToUser`)

The sync uses a two-step prioritized match:

1. `Contact.Email = User.Email` (primary)
2. `Contact.Email + '.smi' = User.Username` (fallback)

For Dillon Oergel, **both** would match — the sync was simply never run.

### Scope of the Problem

A SOQL query against the org confirms this affects multiple contacts:

```
SELECT Id, Name, Email, User_Lookup__c
FROM Contact
WHERE Id IN (SELECT Contact__c FROM Event_Participant__c WHERE Event_Registration__c != null)
AND User_Lookup__c = null
```

At least 10 affected contacts confirmed (partial result), including Dillon Oergel, Sigrid Lee, Tony Voss, and others.

---

## Desired End State

1. All existing event participants whose Contact has a null `User_Lookup__c` but a matching User record — display as clickable profile links.
2. New participants added in the future are auto-synced so they display correctly from the first page load.

---

## What We're NOT Doing

- Not changing the matching logic in `syncContactToUser` / `bulkSyncContactsToUsers` (it already works)
- Not changing the `ParticipantWrapper` or the wire service shape
- Not changing how Users are matched (Email > Username.smi pattern stays)
- Not adding a separate manual "sync" button to the UI

---

## Key File Locations

| File                                                                                    | Purpose                                                                       |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `force-app/main/default/classes/EventParticipantRedirectHelper.cls`                     | Apex — `syncContactToUser`, `bulkSyncContactsToUsers`, `getEventParticipants` |
| `force-app/main/default/classes/EventParticipantRedirectHelperTest.cls`                 | Apex tests                                                                    |
| `force-app/main/default/lwc/eventParticipantRelatedList/eventParticipantRelatedList.js` | LWC — `loadParticipants`, participant rendering                               |

---

## Implementation Plan

### Phase 1: Data Fix — Backfill Existing Null Mappings

Run anonymous Apex to sync all existing contacts that are event participants with a null `User_Lookup__c`. This is a one-time repair and unblocks all currently-affected participants immediately.

**Verification Query (run before and after):**

```apex
// Before: count contacts with null User_Lookup__c that are participants
List<Contact> unsynced = [
    SELECT Id, Name, Email
    FROM Contact
    WHERE Id IN (SELECT Contact__c FROM Event_Participant__c)
    AND User_Lookup__c = null
    AND Email != null
];
System.debug('Unsynced participant contacts: ' + unsynced.size());
```

**Backfill Script (Anonymous Apex):**

```apex
// Collect all participant contact IDs with null User_Lookup__c
List<Contact> contacts = [
    SELECT Id
    FROM Contact
    WHERE Id IN (SELECT Contact__c FROM Event_Participant__c WHERE Event_Registration__c != null)
    AND User_Lookup__c = null
    AND Email != null
];

List<String> contactIds = new List<String>();
for (Contact c : contacts) {
    contactIds.add(c.Id);
}

System.debug('Syncing ' + contactIds.size() + ' contacts');

// Use existing bulk sync method
List<EventParticipantRedirectHelper.SyncResult> results =
    EventParticipantRedirectHelper.bulkSyncContactsToUsers(contactIds);

Integer successCount = 0;
Integer failCount = 0;
for (EventParticipantRedirectHelper.SyncResult r : results) {
    if (r.success) successCount++;
    else failCount++;
}

System.debug('Sync complete. Success: ' + successCount + ', Failed: ' + failCount);
```

**Run with:**

```
sf apex run --file scripts/backfill-contact-user-sync.apex --target-org smi
```

#### Phase 1 Success Criteria

- [x] Backfill script runs without error
- [x] `successCount` is non-zero in debug output — 38 contacts synced, 0 failures
- [x] Dillon Oergel (`003Um00001SEmTxIAL`) now has `User_Lookup__c = 005Um00000B6gflIAB`
- [ ] Navigate to the event page in Experience Cloud — Dillon Oergel appears as a clickable link

---

### Phase 2: Auto-Sync on Participant Load (Preventive)

After `loadParticipants` returns in the LWC, check for any participants with `hasUser = false`. If found, call `bulkSyncContactsToUsers` for those contacts. If any sync succeeds, reload the participants. This self-heals newly-added participants on the next page view.

#### Changes Required

##### 1. `eventParticipantRelatedList.js`

Add import for `bulkSyncContactsToUsers`:

```js
import bulkSyncContactsToUsers from "@salesforce/apex/EventParticipantRedirectHelper.bulkSyncContactsToUsers";
```

Add a private `syncMissingUsers` method:

```js
async syncMissingUsers(eventId) {
    const missing = this.participants
        .filter((p) => !p.hasUser && p.contactId)
        .map((p) => p.contactId);

    if (missing.length === 0) return;

    try {
        const results = await bulkSyncContactsToUsers({ contactIds: missing });
        const anySuccess = results.some((r) => r.success);
        if (anySuccess) {
            // Reload participants now that User_Lookup__c is populated
            this._foundWorkingId = false;
            this._isLoadingParticipants = false;
            await this.loadParticipants(eventId);
        }
    } catch (e) {
        // Sync failure is non-critical — participants still display as grey names
        console.error("Error syncing missing users:", e);
    }
}
```

In `loadParticipants`, after `this.participants = [...participants]` (line ~323), call `syncMissingUsers`:

```js
this.participants = [...participants];
this._eventIdFromUrl = eventId;
this._foundWorkingId = true;
this.error = null;

// Async: try to resolve any missing user links without blocking render
this.syncMissingUsers(eventId);
```

> **Why async/non-blocking?** The sync call updates Contact records and re-fetches participants. This should not delay the initial render. Users will see the list immediately; if a sync resolves a missing link, the list will re-render with the link shortly after.

##### 2. No Apex changes needed for Phase 2

`bulkSyncContactsToUsers` already handles the sync. The wire service's cached version of `getEventParticipants` may return stale data — the manual `loadParticipants` call in `syncMissingUsers` bypasses the cache via imperative Apex.

#### Phase 2 Success Criteria

- [ ] LWC deploys without errors
- [ ] Add a new participant whose Contact has `User_Lookup__c = null` (but a matching User exists) → the name initially shows grey, then updates to a link within a few seconds
- [ ] No errors thrown or shown to the user during sync
- [ ] Participants who already have `User_Lookup__c` populated are unaffected

---

### Phase 3: Auto-Sync on `addParticipant` (Apex)

When an event leader adds a participant via the component, attempt to sync the Contact→User mapping at insert time. This prevents the two-step experience in Phase 2 for newly-added participants.

#### Changes Required

##### `EventParticipantRedirectHelper.cls` — `addParticipant` method

After `insert newParticipant;` and before the re-query, add:

```apex
// Attempt to sync Contact→User mapping for the new participant
// This is best-effort — failure does not prevent the participant from being added
try {
    syncContactToUser(contactId);
} catch (Exception syncEx) {
    System.debug('Contact→User sync failed (non-critical): ' + syncEx.getMessage());
}
```

The existing re-query already reads `Contact__r.User_Lookup__c`, so if the sync succeeds, the returned `ParticipantWrapper` will already have `hasUser = true`.

#### Phase 3 Success Criteria

- [x] Apex deploys without errors — all 39 tests pass (100%)
- [ ] Add a new participant via the component whose Contact has `User_Lookup__c = null` (but a matching User exists) → renders immediately as a link
- [ ] Test: add participant whose Contact has NO matching User → still adds successfully, renders as grey name

---

### Phase 4: Fix and Activate the `User_to_Contact_Sync_Trigger` Flow

#### Background — Why the Flow Never Worked

Two flows were built to handle this sync but neither is active:

| Flow                           | Status         | Problem                                                         |
| ------------------------------ | -------------- | --------------------------------------------------------------- |
| `User_to_Contact_Sync_Trigger` | `InvalidDraft` | Never activated; assignment logic is wrong                      |
| `Sync_User_to_Contact`         | `Draft`        | Autolaunched with `triggerType = None` — no trigger, never runs |

`User_to_Contact_Sync_Trigger` is the intended automatic trigger (fires on User create/update), but it has two bugs:

1. **Wrong trigger type**: Configured as `RecordBeforeSave` on User. Before-save flows can only modify the triggering record — they cannot perform DML on related records like Contact. Updating `Contact.User_Lookup__c` requires an **after-save** flow.

2. **Wrong assignment target**: The `Assign_User_to_Contact` element assigns `$Record.User_Lookup__c = $Record.Id`, which writes back to the User record itself — not to the Contact. There is no Record Update element for the Contact at all, so even if activated, `Contact.User_Lookup__c` would never be set.

#### Changes Required

##### `User_to_Contact_Sync_Trigger.flow-meta.xml`

The flow logic is otherwise sound — the Contact lookup by `Contact.Email = User.Email OR Contact.Email = User.Username` is correct. The following must change:

1. **Change trigger type** from `RecordBeforeSave` to `RecordAfterSave`:

    ```xml
    <triggerType>RecordAfterSave</triggerType>
    ```

2. **Fix the assignment target**: Instead of assigning to `$Record.User_Lookup__c` (the User), assign to a Contact SObject variable:
    - Add a Contact variable (e.g. `ContactToUpdate`)
    - In the assignment: `ContactToUpdate.Id = Get_Contact_Record.Id`, `ContactToUpdate.User_Lookup__c = $Record.Id`

3. **Add a Record Update element** that writes `ContactToUpdate` to the database (replacing the current connector from `Assign_User_to_Contact` back to `Get_Contact_Record`).

4. **Activate the flow**: Change `<status>InvalidDraft</status>` to `<status>Active</status>`.

The corrected flow shape:

```
Start (After-Save, User CreateAndUpdate)
  → Get_Contact_Record (by email match)
  → Contact_Found? (decision)
      Yes → Check_Need_Update (Contact.User_Lookup__c != User.Id?)
                Yes → Assign ContactToUpdate (Id + User_Lookup__c)
                      → Update_Contact_Record (DML)
      No  → [end]
```

#### Phase 4 Success Criteria

- [x] Flow deploys without errors
- [x] Flow status is `Active` in Setup → Flows (activated manually in WUI; CLI metadata deploy sets structure but activation requires WUI confirmation)
- [ ] Create a new community User whose email matches an existing Contact → `Contact.User_Lookup__c` is populated automatically within seconds
- [ ] Update an existing User's email to match a Contact with null `User_Lookup__c` → same result
- [ ] No errors appear in Setup → Apex Jobs or Debug Logs for the flow

---

## Testing Strategy

### Manual Test Cases

| #   | Scenario                                                                                             | Expected Result                                                           |
| --- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 1   | Existing participant with null `User_Lookup__c` but matching User (e.g. Dillon Oergel after Phase 1) | Renders as clickable link                                                 |
| 2   | Participant with null `User_Lookup__c`, no matching User                                             | Renders as grey non-clickable name                                        |
| 3   | Participant with populated `User_Lookup__c`                                                          | Renders as clickable link (unchanged)                                     |
| 4   | Add participant (Phase 3): Contact has matching User                                                 | Immediately renders as link in returned wrapper                           |
| 5   | Add participant (Phase 3): Contact has no matching User                                              | Adds successfully, renders as grey name                                   |
| 6   | Page load with mixed participants (some synced, some not) after Phase 2                              | All synced participants get links; unsynced get links after a brief delay |
| 7   | New User created with email matching a Contact (Phase 4)                                             | `Contact.User_Lookup__c` auto-populated; no manual sync needed            |

### Apex Unit Tests to Add

In `EventParticipantRedirectHelperTest.cls`:

- `addParticipant_syncsContactToUser_whenMatchingUserExists` — after `addParticipant` returns, verify `wrapper.hasUser == true`
- `addParticipant_succeeds_whenNoMatchingUser` — Contact with no matching User still returns a wrapper with `hasUser == false`

---

## Execution Order

1. **Phase 1 first** — immediate data fix, unblocks current affected participants with zero code deploy risk
2. **Phase 3 next** — Apex only, prevents the issue for all future `addParticipant` calls
3. **Phase 4 next** — fix and activate the trigger flow so all future User creates/updates auto-sync to Contact; this is the proper long-term prevention
4. ~~**Phase 2**~~ — Dropped. Phases 1, 3, and 4 together fully cover the problem; the LWC auto-sync adds complexity without meaningful benefit now that the flow is active and `addParticipant` syncs inline.

---

## References

- Component: `force-app/main/default/lwc/eventParticipantRelatedList/`
- Apex: `force-app/main/default/classes/EventParticipantRedirectHelper.cls`
- Trigger flow (broken): `force-app/main/default/flows/User_to_Contact_Sync_Trigger.flow-meta.xml`
- Autolaunched sync flow (inactive): `force-app/main/default/flows/Sync_User_to_Contact.flow-meta.xml`
- Confirmed broken contact: `003Um00001SEmTxIAL` (Dillon Oergel)
- Confirmed matching user: `005Um00000B6gflIAB`
