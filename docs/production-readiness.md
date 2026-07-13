# BabyRelay - Production Readiness

State of the app as a release candidate. The app remains local-first when
provider keys are absent, and switches on production services at runtime when
the build supplies the expected `--dart-define` values. No secrets live in this
repo (see `lib/core/config/app_config.dart`).

Provider creation status is tracked in `docs/provider-setup.md`.

## Implemented

- **Core product**: onboarding → soft paywall → Today
  (one-tap sleep, quick logs, time-rail timeline, next-up guidance) →
  timely review prompt after a useful tracking or handoff action →
  care team → settings.
- **Multi-child**: unlimited children per family (free tier: 1 child,
  owner + 1 caregiver), per-child events, sleep state, nap counts, handoff.
- **Persistence + sync seam**: versioned JSON schema
  (`FamilyState.schemaVersion = 1`) in SharedPreferences behind `LocalStore`,
  plus optional `FamilySyncAdapter`. The app never shipped, so v1 IS the clean
  multi-child shape - there is **no pre-launch migration code**. Unknown/newer
  or corrupt payloads start fresh instead of crashing.
- **Firebase sync**: `FirestoreFamilySyncAdapter` signs in anonymously, stores
  small family metadata at `families/{familyId}`, stores children, caregivers,
  and care events in subcollections, maintains `inviteCodes/{code}`, watches
  bounded recent event changes, persists them locally, and supports
  join-by-code. `firestore.rules` ships with invite-aware family read/update
  rules and subcollection access rules.
- **Remote sleep wake-up path**: devices persist a stable local device ID,
  register FCM tokens, and, on iOS, bridge ActivityKit push-to-start/update
  tokens into Firestore. Cloud Functions fan out sleep event writes to other
  family devices: iOS receives ActivityKit start/update/end pushes and Android
  receives foreground/background ongoing-sleep notification messages.
- **Subscriptions**: `PurchaseService` (abstract) + debug/test-only
  `LocalPurchaseService` + release `SuperwallPurchaseService`. Superwall
  configures without blocking first paint and owns paywall presentation,
  StoreKit/Play Billing purchases, restore, receipt state, and entitlement
  updates. Product IDs are `babyrelay_pro_special_annual`,
  `babyrelay_pro_monthly`, and `babyrelay_pro_annual`; entitlement `pro`.
  Successful purchase/restore also
  marks the shared family as BabyRelay Family active so extra-child/caregiver
  gates and join-by-code evaluate the family plan, not only the joining
  device's local subscription status.
- **Invites**: pure-Dart `InviteService` — unambiguous 6-char codes,
  deterministic `https://babyrelay.app/join/<code>` payload, share text, and a
  scannable QR code in the invite sheet. AppRefer install attribution restores
  a validated `invite_code` into the Join screen, keeps it pending across
  relaunch until join or dismissal, then suppresses the cached attribution.
- **Analytics**: allowlist-only event names, enum-like params asserted in
  debug, no child/caregiver names ever logged. Debug-log sink locally; Firebase
  Analytics sink when Firebase is configured.
- **Crash/support/attribution**: Crashlytics and FCM init with Firebase,
  Gleap-backed in-app support with email fallback, and AppRefer SDK/ATT startup
  plus a Superwall identity bridge controlled by `APPREFER_API_KEY`.
- **Privacy**: versioned export envelope (app, appVersion, schemaVersion,
  exportedAt), confirmed destructive deletes (per-child and all-data).
- **Settings**: integration status list (per-provider configured/not, debug
  builds only), support email row, debug-only demo rows (`Load sample day`,
  `Reset entitlement`) that never appear in release builds.
- **Platform**: iPhone-only, portrait-only, iOS 15+; Android package
  `com.ruvixlabs.babyrelay` now has a Flutter Android target, Firebase config,
  adaptive launcher icons, and a passing debug APK/device smoke.
- **Export compliance**: iOS Info.plist declares
  `ITSAppUsesNonExemptEncryption=false`; the app uses standard
  platform/network encryption only.
- **Tests**: engine, handoff, repository (schema, isolation, merge),
  purchases (all outcomes), invites, and widget flows incl. onboarding paywall,
  timely tracking/handoff review prompts,
  success/cancel/fail/restore.

## Live Provider Status

| Provider | Status | Notes |
|---|---|---|
| Firebase | Live optimized sync + hardened remote-sleep backend smoke passed; iOS APNs configured | Project `babyrelay-ruvix`; iOS app `com.ruvixlabs.babyrelay`; Android app `com.ruvixlabs.babyrelay` / `1:500197010265:android:cf90d1f6dc5b788a287a48`; Web app `1:500197010265:web:d6c4297117240e90287a48`; Firestore `(default)` in `nam5`; plist and `google-services.json` are bundled in the platform targets. Anonymous Auth is enabled. Firestore rules are deployed as ruleset `22a5e94c-4d73-433e-a5d5-d71b9537f7f3`. Cloud Function `onSleepEventWritten` is active as Gen 2 Node.js 22 revision `onsleepeventwritten-00003-pon` in `us-central1`, with its Eventarc trigger preserved in `nam5`. A 2026-07-09 two-user release smoke proved invite join, device/activity collection listing, caregiver self-leave, post-leave member-only denial, a sleep-event trigger, two Cloud Run `200` requests, and synthetic cleanup. The Ruvix APNs auth key is configured in both development and production FCM slots for the exact BabyRelay iOS app. |
| AppRefer | Foundation configured; Superwall webhook linked | App `app_16e4ca28f81`; link `babyrelay-meta`; live/test SDK keys stored in `mc-vault`; SDK enabled. Canonical App Store and Play destinations are configured. Valid deferred `invite_code` attribution opens the prefilled Join screen and remains pending across relaunch until joined/dismissed; the handled cached attribution is then suppressed. Superwall integration reads connected, uses an encrypted app-scoped secret, and receives nine subscription lifecycle event types at endpoint `ep_3GICNMh0fwHjw7cVSrDamNnjoVy`. Release-proven attribution still requires a real paid click → TestFlight/store install/open → sandbox/production purchase readback. |
| Superwall | iOS + Android apps, products, paywalls, campaigns, and iOS tracking configured | Ruvix org `24639`; BabyRelay project `26262`; iOS app `49825`; Android app `49826`. Both apps use entitlement `pro`. iOS paywall `242422` and Android paywall `242424` are published with special annual `$29.99`, annual `$59.99` (7-day trial), and monthly `$9.99`. Campaigns `95002`/`95003` cover `onboarding_complete`, `caregiver_limit`, `child_limit`, and `settings_upgrade`. ASC production and sandbox V2 notification URLs both read back on Superwall. Android RTDN/Pub/Sub remains pending. |
| AppStore Co-Pilot | Project + subscription catalog/legal docs/screenshots synced | Ruvix owner `joe@ruvixlabs.com`; project `irq0wa833wWMRsASUxfK`; iOS app ID `6779147183`; Firebase project/app IDs are linked and the deleted subscription-provider project link has been cleared. Ruvix account-level App Store credentials exist. ASC subscription group `22150100` and all three products are synced into Co-Pilot. Privacy Policy and Terms of Service are published, Support URL is `https://ruvixlabs.com`, and the approved v3 `gpt-image-2` screenshots are staged. |
| App Store Connect | Build valid, attached, and internally testing; web-only declarations remain | App ID `6779147183`, name `BabyRelay: Shared Baby Care`, SKU `BabyRelay`; editable version `1.0` is in `PREPARE_FOR_SUBMISSION`. Signed build `1.0 (3)` (`59a88169-b775-4a97-aa98-50977cbccaad`) is Apple `VALID`, attached to version 1.0, and `IN_BETA_TESTING` in `BabyRelay Internal`; TestFlight validation is clean. Metadata, six `1320x2868` screenshots, categories, `4+` age rating, content rights, published privacy nutrition, review contact/notes, free app price, and 175-territory availability are complete. All three subscriptions are `READY_TO_SUBMIT` and priced in all 175 territories: special annual `$29.99`, monthly `$9.99`, annual `$59.99` with a 7-day trial. Add for Review is narrowed to the web-only regulated-medical-device declaration; the three first-time subscriptions must then be selected on version 1.0. Final submission remains intentionally held for physical push/Live Activity and sandbox purchase/restore proof. |
| Google Play | Draft app/listing/subscriptions/app-content created | Ruvix Play app `4973846096696226350`, package `com.ruvixlabs.babyrelay`, title `BabyRelay: Shared Baby Care`. Listing metadata, support email, approved glow-face icon, and six shared-care phone screenshots are uploaded in draft. App content is caught up. Play subscriptions are active: `babyrelay_pro_monthly` (`monthly`, `$9.99`, no trial), `babyrelay_pro_annual` (`annual`, `$59.99`, 7-day trial), and `babyrelay_pro_special_annual` (`special-annual`, `$29.99`, no trial), all across `173` regions. Android upload signing, first AAB/internal-track upload, and Superwall RTDN/Pub/Sub are pending. |

## Build Defines

```bash
flutter build ios --release \
  --dart-define=FIREBASE_CONFIGURED=true \
  --dart-define=SUPERWALL_IOS_API_KEY=<from mc-vault: babyrelay-superwall-ios-api-key> \
  --dart-define=GLEAP_SDK_KEY=<from mc-vault> \
  --dart-define=APPREFER_API_KEY=<from mc-vault: babyrelay-apprefer-api-key> \
  --dart-define=APPREFER_LINK_ID=babyrelay-meta

flutter build apk --debug \
  --dart-define=FIREBASE_CONFIGURED=true \
  --dart-define=SUPERWALL_ANDROID_API_KEY=<from mc-vault: babyrelay-superwall-android-api-key> \
  --dart-define=APPREFER_API_KEY=<from mc-vault: babyrelay-apprefer-api-key> \
  --dart-define=APPREFER_LINK_ID=babyrelay-meta
```

Debug builds keep local fallback behavior when provider keys are omitted.
Release iOS/Android builds fail closed unless the platform Superwall key and
live AppRefer key are supplied.

## Remaining Provider Work

| Follow-up | Needs | Where it lands |
|---|---|---|
| In-app two-device join smoke | Manual device/TestFlight session or simulator UI automation that can tap/type into Flutter | Backend client smoke has passed live Auth/Firestore rules against the optimized subcollection model. Still worth confirming the exact invite-code UI flow end to end in a running app. |
| Universal/deep links | Platform intent/associated-domain declarations are committed. The domain still needs AASA + Android `assetlinks.json` and a `/join/<code>` fallback route that forwards first installs through AppRefer with `invite_code=<code>`. | Join links open the installed app directly; first installs recover the prefilled invite after the store handoff |
| Superwall sandbox purchase | TestFlight/sandbox and Play test builds with the platform SDK keys | Validate all three products, restore, remote placements, and entitlement `pro` end to end |
| Android upload/release track | BabyRelay Android upload signing + first AAB internal track upload | Validate installable release artifact, Play signing, and publishing overview readiness |
| Android Superwall RTDN | Correct Ruvix GCP/Pub/Sub authority and Play RTDN wiring | Complete server-side Android subscription notifications, then validate purchase/renewal/cancel readback |
| Remote sleep push delivery | TestFlight/physical iPhone and Android push smoke with real device tokens | Backend deploy and rules/function smoke are done; Apple push capability and both Firebase APNs slots are configured. Remaining proof is real owner sleep start/end waking the caregiver lock-screen Live Activity and Android ongoing notification without opening the caregiver app. |
| AppRefer paid-path proof | Real paid click and physical/TestFlight install/open/purchase | Store destinations, SDK key injection, Superwall identity bridge, and webhook are configured; read back the complete click → install/open → purchase join before paid acquisition. |
| ASC web-only completion | Reauthenticate the registered Ruvix ASC browser profile | Set regulated medical device to `No`, select all three first-time subscriptions on version 1.0, and add the version to the draft review submission. Do not press final Submit until physical QA passes. |
| App Store assets/metadata | en-US launch metadata is documented in `docs/app-store-metadata.md` and reflected in AppStore Co-Pilot project `irq0wa833wWMRsASUxfK`. Privacy Policy, Terms, Support URL, six screenshots, categories, age rating, content rights, privacy nutrition, review contact/notes, app pricing, 175-territory availability, build selection, and subscription pricing are complete. | AppStore Co-Pilot / ASC |

## Pre-submission checklist (when credentials exist)

1. Run a final in-app two-device UI smoke for invite-code entry and remote
   push delivery. Backend anonymous Auth, invite-aware Firestore rules, join,
   device/activity listing, caregiver self-leave, member-only denial, remote
   sleep function trigger, and cleanup passed live on 2026-07-09.
2. Reauthenticate the registered Ruvix ASC profile, set regulated medical
   device to `No`, and select the three first-time subscriptions on version
   1.0. Build `1.0 (3)` is already valid, attached, and in internal testing.
3. Run Superwall sandbox purchases and restore against the published iOS and
   Android paywalls.
4. Run `flutter analyze` + `flutter test`; full `app-presubmission` skill.
5. Verify free-tier gates (2nd child, 3rd caregiver) against App Review
   guidelines with the live paywall.
