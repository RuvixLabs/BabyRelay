# BabyRelay Firebase Sync Smoke - 2026-06-22

This folder captures the sync/join verification pass for BabyRelay.

## Simulator Launch

- Owner simulator: Firebase-enabled BabyRelay build installed and launched.
- Joiner simulator: the same Firebase-enabled BabyRelay build installed and
  launched.
- Screenshots:
  - `owner_launch.png`
  - `joiner_launch.png`

The local simulator tooling in this worker could install and launch the app,
but could not reliably tap/type through Flutter UI because `simctl` does not
provide tap/type commands here and `idb_companion` is missing. The backend smoke
below was therefore run through the Firebase client REST APIs using two
anonymous users, not admin credentials.

## Live Backend Smoke

Project: `babyrelay-ruvix`

Passed flow:

1. Owner anonymous Auth token issued.
2. Joiner anonymous Auth token issued.
3. Owner created a family document.
4. Owner created an invite code document.
5. Joiner read the family through the invite-code rule before membership.
6. Joiner updated family membership through invite-aware Firestore rules.
7. Owner wrote a shared feed event after the join.
8. Joiner read the owner-written shared event.
9. Smoke invite/family cleanup completed.

Result marker:

```text
LIVE_FIREBASE_SYNC_SMOKE_PASS
```

Provider state changed during the pass:

- Anonymous Auth enabled for `babyrelay-ruvix`.
- Firestore rules deployed to the `cloud.firestore` release as ruleset
  `557fed9a-ba93-4639-815c-c5a3dd594abb`.
