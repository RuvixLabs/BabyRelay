# BabyRelay - Production Readiness

State of the app as a release candidate. The app remains local-first when
provider keys are absent, and switches on production services at runtime when
the build supplies the expected `--dart-define` values. No secrets live in this
repo (see `lib/core/config/app_config.dart`).

Provider creation status is tracked in `docs/provider-setup.md`.

## Implemented

- **Core product**: onboarding → native rating gate → soft paywall → Today
  (one-tap sleep, quick logs, time-rail timeline, next-up guidance) →
  handoff sheet → care team → settings.
- **Multi-child**: unlimited children per family (free tier: 1 child,
  owner + 1 caregiver), per-child events, sleep state, nap counts, handoff.
- **Persistence + sync seam**: versioned JSON schema
  (`FamilyState.schemaVersion = 1`) in SharedPreferences behind `LocalStore`,
  plus optional `FamilySyncAdapter`. The app never shipped, so v1 IS the clean
  multi-child shape - there is **no pre-launch migration code**. Unknown/newer
  or corrupt payloads start fresh instead of crashing.
- **Firebase sync**: `FirestoreFamilySyncAdapter` signs in anonymously, stores
  the family snapshot at `families/{familyId}`, maintains `inviteCodes/{code}`,
  watches remote changes, persists them locally, and supports join-by-code.
  `firestore.rules` ships with invite-aware family read/update rules.
- **Subscriptions**: `PurchaseService` (abstract) + `LocalPurchaseService` +
  `RevenueCatPurchaseService`. Purchase/restore UX covers success, cancelled,
  failed, and nothing-to-restore states, with busy guards and store-driven
  prices when offerings are available. Product IDs:
  `babyrelay_pro_special_annual`, `babyrelay_pro_monthly`,
  `babyrelay_pro_annual`; entitlement `pro`.
- **Invites**: pure-Dart `InviteService` — unambiguous 6-char codes,
  deterministic `https://babyrelay.app/join/<code>` payload, share text, and a
  scannable QR code in the invite sheet.
- **Analytics**: allowlist-only event names, enum-like params asserted in
  debug, no child/caregiver names ever logged. Debug-log sink locally; Firebase
  Analytics sink when Firebase is configured.
- **Crash/support/attribution**: Crashlytics and FCM init with Firebase,
  Gleap-backed in-app support with email fallback, and an AppRefer/ATT startup
  seam controlled by `APPREFER_LINK_ID`.
- **Privacy**: versioned export envelope (app, appVersion, schemaVersion,
  exportedAt), confirmed destructive deletes (per-child and all-data).
- **Settings**: integration status list (per-provider configured/not, debug
  builds only), support email row, debug-only demo rows (`Load sample day`,
  `Reset entitlement`) that never appear in release builds.
- **Platform**: iPhone-only, portrait-only, iOS 15+.
- **Tests**: engine, handoff, repository (schema, isolation, merge),
  purchases (all outcomes), invites, and widget flows incl. onboarding rating
  gate + paywall
  success/cancel/fail/restore.

## Live Provider Status

| Provider | Status | Notes |
|---|---|---|
| Firebase | Created | Project `babyrelay-ruvix`; iOS app `com.ruvixlabs.babyrelay`; Firestore `(default)` in `nam5`; plist is bundled in the iOS target. |
| AppRefer | Created | App `app_16e4ca28f81`; link `babyrelay-meta`; live/test SDK keys stored in `mc-vault`. Needs store destination URL before `trk.apprefer.com` can redirect. |
| RevenueCat | Test Store + App Store catalog mapped | Project `26c4f023`; Test Store app `appf68d685da8`; App Store app `app70e3a91be4`; App Store SDK key stored in `mc-vault`; Ruvix in-app purchase key and ASC API key are configured. App Store monthly/annual products are imported, attached to `pro`, and included in the current `default` offering packages alongside Test Store products. App Store special annual product `babyrelay_pro_special_annual` is attached to `pro` in separate `special_offer` offering package `special_annual`. Account email still needs confirmation. Live ASC readback on 2026-06-16 shows Apple server notification URLs are not currently set, so production/sandbox V2 URLs must be re-applied before submission. |
| AppStore Co-Pilot | Project + subscription catalog/legal docs synced | Ruvix owner `joe@ruvixlabs.com`; project `irq0wa833wWMRsASUxfK`; iOS app ID `6779147183`; Firebase project/app IDs and RevenueCat project ID are linked. Ruvix account-level App Store credentials exist. ASC subscription group `22150100` and products `babyrelay_pro_monthly`, `babyrelay_pro_annual`, and `babyrelay_pro_special_annual` are synced into Co-Pilot with pricing/trial metadata. Privacy Policy and Terms of Service are published, and AppStore Co-Pilot compliance currently returns zero issues. RevenueCat direct catalog management still needs a BabyRelay RevenueCat secret API key. |
| App Store Connect | App record + subscriptions created | App ID `6779147183`, name `BabyRelay : Shared Baby Care`, SKU `BabyRelay`; subscription group `22150100`; special annual `6779256297` at `$29.99`, monthly `6779156238` at `$9.99`, annual `6779156833` at `$59.99`; standard monthly/annual have 7-day free trials and review screenshots, while special annual has no trial and its launch-offer screenshot uploaded. All currently read `MISSING_METADATA`, so they still need to be submitted with the App Store version/build. |

## Build Defines

```bash
flutter build ios --release \
  --dart-define=FIREBASE_CONFIGURED=true \
  --dart-define=REVENUECAT_API_KEY=<from mc-vault: babyrelay-revenuecat-ios-sdk-key> \
  --dart-define=GLEAP_SDK_KEY=<from mc-vault> \
  --dart-define=APPREFER_LINK_ID=babyrelay-meta
```

If a define is omitted, that service remains disabled and the app keeps its
local fallback behavior.

## Remaining Provider Work

| Follow-up | Needs | Where it lands |
|---|---|---|
| Deploy Firestore rules | Ruvix Firebase CLI/gcloud context selected, then `firebase -P babyrelay-ruvix deploy --only firestore:rules` | `firestore.rules` |
| Universal/deep links | Apple associated domains + web route for `babyrelay.app/join/<code>` | Join links open the app directly instead of only showing the code |
| RevenueCat sandbox purchase | TestFlight/sandbox build with the App Store SDK key | Validate current/special offerings and entitlement `pro` end to end |
| AppStore Co-Pilot RevenueCat secret | BabyRelay RevenueCat secret API key created/stored | Enables AppStore Co-Pilot RevenueCat catalog tools for project `irq0wa833wWMRsASUxfK` |
| AppRefer redirect | Real App Store URL once the listing exists | `trk.apprefer.com` can redirect; optional future wrapping in `InviteService.decorateLink` |
| App Store assets/metadata | en-US launch metadata is drafted in `docs/app-store-metadata.md` and staged in AppStore Co-Pilot project `irq0wa833wWMRsASUxfK` as history version 7. Privacy Policy is published at `https://appstorecopilot.com/legal/3omln7px/privacy`; Terms of Service is published at `https://appstorecopilot.com/legal/3omln7px/terms`; both are linked from the app. AppStore Co-Pilot compliance detects `hasSubscriptions: true` and currently returns zero issues. Raw simulator screenshots live in `artifacts/app_store_screenshots/raw/2026-06-16/`, the deterministic 6.9-inch set is staged in `artifacts/app_store_screenshots/final/2026-06-16/iphone_69/`, and a stronger no-paywall pure `gpt-image-2` story-led candidate is saved in `artifacts/app_store_screenshots/gpt-image-2-story-v2/2026-06-16/iphone_69/` plus uploaded to a separate AppStore Co-Pilot storage path for review. Nano Banana generation was attempted but blocked by insufficient Kie credits. Still needs final screenshot selection, privacy nutrition, live screenshot push to ASC, build, review information, and live ASC publish. | AppStore Co-Pilot pipeline |

## Pre-submission checklist (when credentials exist)

1. Deploy Firestore rules and confirm anonymous join-by-code in a production
   Firebase build.
2. Run a RevenueCat sandbox purchase and restore with the live App Store
   offering.
3. Run `flutter analyze` + `flutter test`; full `app-presubmission` skill.
4. Verify free-tier gates (2nd child, 3rd caregiver) against App Review
   guidelines with the live paywall.
