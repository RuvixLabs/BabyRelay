# BabyRelay — Production Readiness

State of the app as a release candidate, split into what is **done and local**
versus what is **blocked on credentials / live providers**. No secrets live in
this repo; every provider key arrives at build time via `--dart-define`
(see `lib/core/config/app_config.dart`).

Provider creation status is tracked in `docs/provider-setup.md`.

## Implemented (local-first, shippable)

- **Core product**: onboarding → Today (one-tap sleep, quick logs, time-rail
  timeline, next-up guidance) → handoff sheet → care team → settings.
- **Multi-child**: unlimited children per family (free tier: 1 child,
  owner + 1 caregiver), per-child events, sleep state, nap counts, handoff.
- **Persistence**: versioned JSON schema (`FamilyState.schemaVersion = 1`) in
  SharedPreferences behind the `LocalStore` seam. The app never shipped, so
  v1 IS the clean multi-child shape - there is **no pre-launch migration code**.
  Unknown/newer/corrupt payloads start fresh instead of crashing.
- **Subscriptions**: `PurchaseService` (abstract) + `LocalPurchaseService`.
  Full purchase/restore UX with distinct success / cancelled / failed /
  nothing-to-restore states, error copy, busy guard, persisted entitlement,
  and test hooks (`nextPurchaseOutcome`, `failNextRestore`, zero
  `actionDelay`). Product-id placeholders: `babyrelay_pro_monthly`,
  `babyrelay_pro_annual`; entitlement `pro`.
- **Invites**: pure-Dart `InviteService` — unambiguous 6-char codes,
  deterministic `https://babyrelay.app/join/<code>` payload + share text.
  The QR in the invite sheet is a **decorative glyph**, not scannable; the
  real QR ships with the deep-link handler.
- **Analytics**: allowlist-only event names, enum-like params asserted in
  debug, no child/caregiver names ever logged. Debug-log sink today.
- **Privacy**: versioned export envelope (app, appVersion, schemaVersion,
  exportedAt), confirmed destructive deletes (per-child and all-data).
- **Settings**: integration status list (per-provider configured/not, debug
  builds only), support email row, debug-only demo rows (`Load sample day`,
  `Reset entitlement`) that never appear in release builds.
- **Platform**: iPhone-only, portrait-only.
- **Tests**: engine, handoff, repository (schema, isolation, merge),
  purchases (all outcomes), invites, and widget flows incl. paywall
  success/cancel/fail/restore.

## Live Provider Status

| Provider | Status | Notes |
|---|---|---|
| Firebase | Created | Project `babyrelay-ruvix`; iOS app `com.ruvixlabs.babyrelay`; Firestore `(default)` in `nam5`; plist is bundled in the iOS target. |
| AppRefer | Created | App `app_16e4ca28f81`; link `babyrelay-meta`; live/test SDK keys stored in `mc-vault`. Needs store destination URL before `trk.apprefer.com` can redirect. |
| RevenueCat | Account created, onboarding blocked | Login is stored in `mc-vault`; dashboard project/catalog creation is blocked on RevenueCat's post-signup verification/onboarding state. |

## Remaining Provider Work

| Follow-up | Needs | Where it lands |
|---|---|---|
| Firebase Auth + Firestore sync | Add Flutter Firebase packages + repository implementation | Firestore-backed `FamilyRepository` behind the same API; model in `docs/plans/core/overview.md`; set `--dart-define=FIREBASE_CONFIGURED=true` |
| Firebase Analytics/Crashlytics/Messaging | Add Flutter Firebase packages + runtime init | Sink inside `AnalyticsService.logEvent`; crash + push init in `main.dart` |
| RevenueCat | Finish dashboard onboarding, SDK key, products in ASC matching `ProductIds` | RevenueCat-backed `PurchaseService` implementation; entitlement `pro` |
| Real join flow | Firebase + universal links | Replace the local on-device add path in `care_team_screen.dart`; scannable QR from `InvitePayload.url` |
| AppRefer attribution | App Store URL + `APPREFER_LINK_ID=babyrelay-meta` | Override `InviteService.decorateLink` |
| Gleap support chat | `GLEAP_SDK_KEY` | Settings support row (email fallback already live) |
| App Store assets/metadata | ASC app record | AppStore Copilot pipeline |

## Pre-submission checklist (when credentials exist)

1. Wire the providers above; flip each Settings status to Configured.
2. Replace local price labels with store-driven offerings (RevenueCat).
3. Run `flutter analyze` + `flutter test`; full `app-presubmission` skill.
4. Verify free-tier gates (2nd child, 3rd caregiver) against App Review
   guidelines with the live paywall.
