# Hide eventParticipantRelatedList for Public Events — Implementation Plan

## Overview

The `eventParticipantRelatedList` LWC is placed on the Experience Cloud event registration page for all events. When an event is marked **Public** (`Event_Registration__c.Public__c = true`), this component should not be displayed. Currently it renders regardless, and because the Apex call fails for public events (likely due to sharing/permissions on `Event_Participant__c` for the community user context), it displays a red error banner: **"Unable to load event participants. Please try again later."**

---

## Current State Analysis

### What exists

- **LWC**: `force-app/main/default/lwc/eventParticipantRelatedList/`
    - Always renders on any event registration page
    - Extracts `Event_Registration__c` ID from the URL path (`/s/event-registration/{id}/...`)
    - Calls `getEventParticipants({ eventId })` via wire and imperatively
    - On Apex error, sets `this.error = "Unable to load event participants. Please try again later."` and shows a red alert banner
    - **Has zero logic to check `Public__c` before rendering or loading data**

- **Apex**: `force-app/main/default/classes/EventParticipantRedirectHelper.cls`
    - `getEventParticipants(String eventId)` — queries `Event_Registration__c` then `Event_Participant__c`
    - Throws `AuraHandledException` on any failure
    - **Never checks `Public__c`**

- **`Public__c` field**: Custom field on `Event_Registration__c`, maintained by three Flows that sync it from `Event.IsVisibleInSelfService`. Field definition metadata is not in source control but the field exists in the org.

### Root Cause

The component has no guard against public events. When a public event page loads:

1. LWC extracts the `Event_Registration__c` ID from the URL
2. Calls `getEventParticipants` which queries `Event_Participant__c`
3. Query fails (community user lacks access, or Apex throws for another reason)
4. `catch` block at `eventParticipantRelatedList.js:317` sets `this.error` → red banner renders

### Key File Locations

| File                                                                                      | Purpose                                       |
| ----------------------------------------------------------------------------------------- | --------------------------------------------- |
| `force-app/main/default/lwc/eventParticipantRelatedList/eventParticipantRelatedList.js`   | LWC controller — add public status check here |
| `force-app/main/default/lwc/eventParticipantRelatedList/eventParticipantRelatedList.html` | LWC template — wrap article in conditional    |
| `force-app/main/default/classes/EventParticipantRedirectHelper.cls`                       | Apex — add `isEventPublic` method here        |
| `force-app/main/default/classes/EventParticipantRedirectHelperTest.cls`                   | Tests — add coverage for new method           |

---

## Desired End State

When a viewer navigates to a Public event registration page:

- The `eventParticipantRelatedList` component renders **nothing** (no card, no error, no empty state)
- No Apex call is made to load participants

When a viewer navigates to a non-Public event registration page:

- Existing behavior is unchanged — the component loads and displays participants normally

### How to Verify

1. Navigate to a Public event's registration URL in Experience Cloud
2. The "Event Participants" card should not appear anywhere on the page
3. No red error banner should be visible
4. Browser network/console should show no failed Apex call for `getEventParticipants`
5. Navigate to a non-Public event → participants still load normally

---

## What We're NOT Doing

- Not changing sharing rules, profiles, or permission sets
- Not modifying how `Public__c` is set or synced (Flows handle this)
- Not changing any other component's behavior
- Not adding a "Private — participants hidden" message; the component simply disappears
- Not modifying the page layout in Experience Builder (the component stays on the layout; it just renders nothing when not applicable)

---

## Implementation Approach

Add an `isEventPublic` Apex method that reads `Public__c` from `Event_Registration__c`. Call it imperatively in the LWC before any participant loading. If the event is public, set a flag and render nothing.

This is intentionally the minimal surface-area fix: one new Apex method, two small LWC changes (one in JS, one in HTML).

---

## Phase 1: Add `isEventPublic` Apex Method

### Overview

Add a cacheable Apex method that accepts an `eventRegistrationId` and returns `true` if `Public__c == true`.

### Changes Required

#### 1. `EventParticipantRedirectHelper.cls`

**File**: `force-app/main/default/classes/EventParticipantRedirectHelper.cls`

Add this method immediately before the `getEventParticipants` method (around line 265):

```apex
@AuraEnabled(cacheable=true)
public static Boolean isEventPublic(String eventRegistrationId) {
    try {
        List<Event_Registration__c> regs = [
            SELECT Id, Public__c
            FROM Event_Registration__c
            WHERE Id = :eventRegistrationId
            LIMIT 1
        ];
        if (regs.isEmpty()) {
            return false;
        }
        return regs[0].Public__c == true;
    } catch (Exception e) {
        System.debug('Error checking event public status: ' + e.getMessage());
        return false;
    }
}
```

**Why `return false` on error?** If the query fails (bad ID, no access), we degrade gracefully — the component will attempt to load participants as before, and the existing error handling takes over. We do not want a bad public-status check to silently hide participants from private events.

#### 2. `EventParticipantRedirectHelperTest.cls`

**File**: `force-app/main/default/classes/EventParticipantRedirectHelperTest.cls`

Add test methods for the new `isEventPublic` method. Review existing test setup patterns in the file and add:

- A test where `Public__c = true` → method returns `true`
- A test where `Public__c = false` → method returns `false`
- A test with an invalid/non-existent ID → method returns `false`

### Success Criteria

#### Automated Verification

- [x] Apex compiles without errors (deploy or `sf project deploy start`)
- [x] Apex tests pass with ≥75% coverage: `sf apex run test --test-level RunLocalTests`
- [x] New `isEventPublic` test methods pass

#### Manual Verification

- [ ] Can call `isEventPublic` from Developer Console anonymous Apex with a known Public event registration ID and get `true`
- [ ] Can call `isEventPublic` with a known non-Public event registration ID and get `false`

**Implementation Note**: After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to Phase 2.

---

## Phase 2: LWC — Check Public Status Before Rendering

### Overview

Import the new `isEventPublic` method into the LWC. Before loading participants, call it. If the event is public, set `isPublicEvent = true` and short-circuit all participant loading. Wrap the template in a conditional so the card renders nothing.

### Changes Required

#### 1. `eventParticipantRelatedList.js`

**File**: `force-app/main/default/lwc/eventParticipantRelatedList/eventParticipantRelatedList.js`

**Add import** at the top (after the existing imports):

```js
import isEventPublic from "@salesforce/apex/EventParticipantRedirectHelper.isEventPublic";
```

**Add property** in the class body (after `showAddParticipant = false;`):

```js
isPublicEvent = false;
```

**Add getter** for the template conditional:

```js
get showComponent() {
  return !this.isPublicEvent;
}
```

**Add a private check method**:

```js
async checkPublicStatus(eventId) {
  if (!eventId) return false;
  try {
    const isPublic = await isEventPublic({ eventRegistrationId: eventId });
    this.isPublicEvent = isPublic === true;
    return this.isPublicEvent;
  } catch (e) {
    // On error, assume not public — fail open so participants still load
    this.isPublicEvent = false;
    return false;
  }
}
```

**Guard `loadParticipants`** — at the very top of the `loadParticipants(eventId)` method, before the existing `if (!eventId) return;` check, add:

```js
// Check public status before loading
const isPublic = await this.checkPublicStatus(eventId);
if (isPublic) {
    this.isLoading = false;
    this._isLoadingParticipants = false;
    return;
}
```

> **Note**: `loadParticipants` is already `async`, so `await` is safe here.

**Guard the wire handler** — in `wiredParticipantsHandler`, add a guard at the very top before the `if (data && data.length > 0)` block:

```js
if (this.isPublicEvent) return;
```

This prevents the wire service from updating state after the public check has already fired.

#### 2. `eventParticipantRelatedList.html`

**File**: `force-app/main/default/lwc/eventParticipantRelatedList/eventParticipantRelatedList.html`

Wrap the entire `<article>` element in a template conditional. Change:

```html
<template>
    <article class="slds-card ...">...</article>
</template>
```

To:

```html
<template>
    <template if:true="{showComponent}">
        <article class="slds-card ...">...</article>
    </template>
</template>
```

### Success Criteria

#### Automated Verification

- [x] LWC deploys without errors: `sf project deploy start --source-dir force-app/main/default/lwc/eventParticipantRelatedList`
- [x] No ESLint errors: `sf scanner run` or project linting tooling
- [x] Existing Apex tests still pass

#### Manual Verification

- [ ] Navigate to a **Public** event registration page in Experience Cloud → "Event Participants" card is completely absent from the page
- [ ] No red error banner is shown on Public event pages
- [ ] No network call to `getEventParticipants` is made on Public event pages (verify in browser DevTools → Network → XHR)
- [ ] Navigate to a **non-Public** event registration page → "Event Participants" card loads normally with participant data
- [ ] Event leader controls (Add Participant, Remove) still function on non-Public events

**Implementation Note**: After completing this phase, pause for manual testing confirmation before marking the task done.

---

## Testing Strategy

### Unit Tests (Apex)

- `isEventPublic` with `Public__c = true` → returns `true`
- `isEventPublic` with `Public__c = false` → returns `false`
- `isEventPublic` with null/invalid ID → returns `false`

### Manual Testing Steps

1. Log into Experience Cloud as a standard community member
2. Navigate to a known **Public** event registration URL (e.g., the April GMM - Knot Your Average Workshop)
3. Confirm the Event Participants card is not shown anywhere on the page
4. Confirm no red error banner appears
5. Navigate to a known **non-Public** (private/club) event registration URL
6. Confirm the Event Participants card renders with correct participant data
7. If you are a leader for that event, confirm Add/Remove participant controls still work

---

## Migration Notes

No data migration needed. The `Public__c` field already exists and is populated by existing Flows. This change only adds a read-path check on top of existing data.

---

## References

- Component: `force-app/main/default/lwc/eventParticipantRelatedList/`
- Apex: `force-app/main/default/classes/EventParticipantRedirectHelper.cls`
- Privacy doc: `docs/articles/event-participant-privacy-solution.md`
- Public field sync flows: `force-app/main/default/flows/Event_Process.flow-meta.xml`, `Event_Process_1.flow-meta.xml`, `Event_Registration_Update_Parent_Event_when_Changed.flow-meta.xml`
