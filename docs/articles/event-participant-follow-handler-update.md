# Event Participant Follow Handler: Tests, Deployment, and Lessons Learned

Over the last round of development we tightened up the `EventParticipantFollowHandler` logic, produced reliable Apex tests, and successfully deployed the trigger + handler bundle into the **webdev5@spokanemountaineers.org** sandbox. This post documents the journey end-to-end so future contributors can replicate the workflow (and avoid the potholes).

## Why We Touched This Area

- Ensure new `Event_Participant__c` records automatically follow the corresponding `Event_Registration__c` record via `EntitySubscription`, matching what Members see in Experience Cloud.
- Deliver reliable unit tests that prove happy path, negative scenarios, and bulk de-duplication.
- Provide a deployable package that clears Salesforce test coverage requirements (>75% for both trigger and handler).

## Highlights

- **Test Data Isolation** – Leveraged `@TestVisible` maps to inject registration/contact data, eliminating automation collisions with existing approval flows.
- **Reusable Fixtures** – Added a helper to fetch a live `Event_Registration__c` id and to create unique contacts + users on demand.
- **Negative Coverage** – Validated missing registration context and contacts without a related user to guarantee early exits remain defensive.
- **Bulk Confidence** – Simulated a 10-record insert twice, verifying de-duplication within the handler and against existing `EntitySubscription` rows (still scoped to the registration record).
- **Community Ready** – When the handler runs inside Experience Cloud we now stamp the site’s `NetworkId` on each `EntitySubscription`, which satisfies Salesforce’s sharing rules for community followers.
- **Verified Deployment** – `sf project deploy start ... --tests EventParticipantFollowHandlerTest` completes cleanly (Deploy ID `0AfUm0000019wgvKAA`, elapsed ~32s).

## Anatomy of the New Tests

| Scenario             | What We Assert                                      | Notes                                                        |
| -------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| Happy Path           | `EntitySubscription` count += 1 on the registration | Confirms attendees follow the page Members actually see.     |
| Missing User         | No subscription created                             | Coverage for contacts without `User_Lookup__c`.              |
| Registration Missing | No subscription created                             | Simulates a missing registration record in test overrides.   |
| Bulk Insert          | Only one subscription exists                        | Confirms composite key dedupe and pre-existing record check. |

All tests rely on helpers such as `createContactWithUser(nextSuffix())` and `fetchAnyRegistrationId()` to guarantee unique context per method.

## Command Reference

```bash
sf project deploy start \
  --source-dir force-app/main/default/classes/EventParticipantFollowHandler.cls \
  --source-dir force-app/main/default/classes/EventParticipantFollowHandlerTest.cls \
  --source-dir force-app/main/default/triggers/EventParticipantTrigger.trigger \
  --target-org webdev5@spokanemountaineers.org \
  --test-level RunSpecifiedTests \
  --tests EventParticipantFollowHandlerTest
```

## What’s Next

- Mirror the test helpers (`testRegById`, contact fixtures) in adjacent trigger suites to unify pattern usage.
- Promote the deployment to higher environments once downstream automation owners sign off.
- Consider surfacing the registration feed in Experience Cloud so members immediately see the updates they auto-follow.

Have questions or want to replicate the setup? Ping the Salesforce dev channel and reference this article—everything you need is here.
