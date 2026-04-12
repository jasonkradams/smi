# Fix License Shuffle Batch — Emergency Downgrade & Algorithm Rewrite Plan

## Context

The `LicenseShuffleBatch` has been running daily since approximately December 2025. As of 2026-04-12:

- **505 Customer Community Plus (Premium) licenses assigned** — this is the hard cap
- **171 non-protected Premium users have ≤5 logins** in the current fiscal period — the batch should be downgrading these users but isn't
- The batch runs without errors (21 chunks, 0 errors/day), making only 1–3 changes per run
- The daily scheduler (`Login History Sync - Daily`) has triggered 120 times and is healthy
- `Fiscal_Year_Login_History__c` has 25,069 records and is being maintained correctly

The root cause is a two-pass correctness bug in `LicenseShuffleBatch`: license decisions are made per-chunk on incomplete data, because `calculatePremiumUsersToKeep()` is called before all users have been collected.

---

## Phase 1: Emergency Script (run immediately)

**Goal**: Free up 30 Premium licenses now by directly downgrading the 30 non-protected Premium users with the fewest logins.

**File**: `scripts/apex/license-sorting/emergency_downgrade_bottom_30.apex`

**Logic**:

1. Determine fiscal year date range (same logic as `countUserLogins()` — last 365 days for Feb–Apr, Feb 1 of current year for May–Dec, Feb 1 of prior year for Jan)
2. Aggregate login counts from `Fiscal_Year_Login_History__c` grouped by user
3. Query all active Premium users who are not protected (not Chair profile, created >90 days ago)
4. Sort ascending by login count, take the bottom 30
5. Update their `ProfileId` to `SM Community Plus Login`
6. Enqueue `LicenseChangeLogQueueable` with reason `"Emergency downgrade - license cap exceeded"`

**Verification after run**:

```
SELECT Profile.UserLicense.Name, COUNT(Id)
FROM User
WHERE IsActive = true
AND Profile.UserLicense.Name IN ('Customer Community Plus', 'Customer Community Plus Login')
GROUP BY Profile.UserLicense.Name
```

Expected: Premium count drops from 505 to 475.

---

## Phase 2: LicenseShuffleBatch Algorithm Rewrite

### Problem: Single-pass per-chunk decision making

The batch processes ~50 users per chunk. On each chunk, `calculatePremiumUsersToKeep()` runs against only the users seen so far (`allUsers` map). Users in early chunks get their licenses changed before later chunks have been seen, so the keep list is built on partial data.

Additionally:

- `targetCalculated` flag is initialized `false` and **never set to `true`** — the recalculation branch on line 91 is dead code
- `getProfileId()` issues a SOQL query per user update (inside a loop)
- `countUserLogins()` issues one `COUNT()` SOQL query per user (50 queries/chunk)

### Fix: Two-pass design

Separate the batch into a **collection phase** (execute) and an **action phase** (finish).

**`execute()`** — collect only, no DML:

- Cast scope to `List<User>`, add to `allUsers` stateful map
- Identify protected users, add to `protectedUserIds`
- Run a single aggregate SOQL query for login counts for all users in this chunk (GROUP BY User\_\_c), merge results into `userLoginCounts` stateful map
- No license changes, no profile lookups

**`finish()`** — act on complete data:

1. Query and cache needed Profile IDs (`SM Community Plus Login`, `SM Community Plus Member`) — two SOQL queries total
2. Call `calculatePremiumUsersToKeep()` once with full `allUsers` and `userLoginCounts`
3. Iterate `allUsers.values()`, build `List<User>` of changes
4. `update usersToUpdate` (all at once, within 10k DML row limit — we have ~1007 users)
5. Enqueue `LicenseChangeLogQueueable` with accumulated logs

**Remove**:

- `targetCalculated` flag (dead code)
- `collectionPhaseComplete` flag (unused)
- `premiumUsersToKeep` calculation from `execute()`
- `getProfileId()` method (replace with cached map in `finish()`)

**Result**: The algorithm sees all users before making any decisions, which is the correct behavior.

### Fix: Batch login count query

Replace the per-user `countUserLogins()` SOQL with a single aggregate query per chunk:

```apex
// In execute(): one query for the whole chunk
Set<Id> chunkUserIds = new Set<Id>();
for (User u : users) chunkUserIds.add(u.Id);

AggregateResult[] counts = [
    SELECT User__c uid, COUNT(Id) cnt
    FROM Fiscal_Year_Login_History__c
    WHERE User__c IN :chunkUserIds
    AND Login_Time__c >= :startDateTime
    GROUP BY User__c
];
for (AggregateResult ar : counts) {
    userLoginCounts.put((Id)ar.get('uid'), (Integer)ar.get('cnt'));
}
// Users with no records default to 0 (already handled by map miss)
```

This reduces SOQL queries from 50/chunk to 1/chunk.

---

## Phase 3: LoginHistoryCleanupBatch — Add Database.Stateful

`LoginHistoryCleanupBatch` tracks `totalRecordsDeleted` and `totalErrors` across chunks but does not implement `Database.Stateful`. These counters reset between chunks. The `finish()` summary always reports 0.

**Fix**: Add `Database.Stateful` to the class declaration.

---

## Phase 4: Update Proposal Doc

Update `docs/proposals/automate-member-license-sorting.md`:

- Mark all Phase 4 and Phase 5 items as complete (schedulers have been running ~4 months)
- Update status from "Ready for Deployment" to "Live — Deployed"
- Note the algorithm bug and this fix plan
- Remove deployment steps that are already done

---

## Implementation Order

1. **Run emergency script** — immediate, no deploy needed ✅ (script written, ready to run)
2. **Rewrite `LicenseShuffleBatch`** — fix execute/finish split, batch login queries, remove dead code ✅
3. **Fix `LoginHistoryCleanupBatch`** — add `Database.Stateful` ✅
4. **Update tests** — removed four dead-code tests, 240/240 passing ✅
5. **Deploy to org** — deployed 2026-04-12, 240/240 org tests passing ✅
6. **Reschedule daily sync** — rescheduled after deploy, next fire 2026-04-13 09:00 ✅
7. **Update proposal doc** ✅

---

## Success Criteria

- Premium license count at or below 475 after emergency script — **pending: run emergency_downgrade_bottom_30.apex**
- Next daily batch run (2026-04-13 09:00) makes correct decisions (downgrades all users with ≤5 logins)
- Batch `finish()` debug log shows correct total counts
- `LoginHistoryCleanupBatch` finish log shows accurate deleted count
- All existing tests pass ✅
