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
- **Subscriptions**: `PurchaseService` (abstract) + `LocalPurchaseService` +
  `RevenueCatPurchaseService`. Purchase/restore UX covers success, cancelled,
  failed, and nothing-to-restore states, with busy guards and store-driven
  prices when offerings are available. Product IDs:
  `babyrelay_pro_special_annual`, `babyrelay_pro_monthly`,
  `babyrelay_pro_annual`; entitlement `pro`. Successful purchase/restore also
  marks the shared family as BabyRelay Family active so extra-child/caregiver
  gates and join-by-code evaluate the family plan, not only the joining
  device's local RevenueCat status.
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
| Firebase | Live optimized sync smoke passed | Project `babyrelay-ruvix`; iOS app `com.ruvixlabs.babyrelay`; Android app `com.ruvixlabs.babyrelay` / `1:500197010265:android:cf90d1f6dc5b788a287a48`; Web app `1:500197010265:web:d6c4297117240e90287a48`; Firestore `(default)` in `nam5`; plist and `google-services.json` are bundled in the platform targets. Anonymous Auth is enabled. Firestore rules are deployed to the `cloud.firestore` release as ruleset `0db384ff-4323-4dcb-a647-c1a5e0fb8b16` using the Ruvix gcloud context and Firebase Rules REST API. A client-side owner/joiner invite-code smoke passed on 2026-06-22 with two anonymous users and no admin bypass against the optimized subcollection model. |
| AppRefer | Created | App `app_16e4ca28f81`; link `babyrelay-meta`; live/test SDK keys stored in `mc-vault`. Needs store destination URLs before `trk.apprefer.com` can redirect to App Store or Play. |
| RevenueCat | Test Store + App Store catalog mapped | Project `26c4f023`; Test Store app `appf68d685da8`; App Store app `app70e3a91be4`; App Store SDK key stored in `mc-vault`; Ruvix in-app purchase key and ASC API key are configured. App Store monthly/annual products are imported, attached to `pro`, and included in the current `default` offering packages alongside Test Store products. App Store special annual product `babyrelay_pro_special_annual` is attached to `pro` in separate `special_offer` offering package `special_annual`. Apple server notification URLs are confirmed set in ASC for production + sandbox, both `V2`. Google Play products now exist, but the RevenueCat Android app, product import, and public SDK key still need to be created from the BabyRelay-specific RevenueCat account. Account email still needs confirmation. |
| AppStore Co-Pilot | Project + subscription catalog/legal docs/screenshots synced | Ruvix owner `joe@ruvixlabs.com`; project `irq0wa833wWMRsASUxfK`; iOS app ID `6779147183`; Firebase project/app IDs and RevenueCat project ID are linked. Ruvix account-level App Store credentials exist. ASC subscription group `22150100` and products `babyrelay_pro_monthly`, `babyrelay_pro_annual`, and `babyrelay_pro_special_annual` are synced into Co-Pilot with pricing/trial metadata, except monthly intentionally has no intro trial. Privacy Policy and Terms of Service are published, Support URL is `https://ruvixlabs.com`, and AppStore Co-Pilot compliance currently returns zero issues. The approved v3 `gpt-image-2` screenshots are staged in Co-Pilot. RevenueCat direct catalog management still needs a BabyRelay RevenueCat secret API key. |
| App Store Connect | App record + metadata/screenshots/categories/age rating/subscriptions/privacy created | App ID `6779147183`, name `BabyRelay: Shared Baby Care`, SKU `BabyRelay`; editable version `1.0` is in `PREPARE_FOR_SUBMISSION`; en-US app info/version metadata and six `1320x2868` screenshots are pushed and read back `COMPLETE`. Primary category is `HEALTH_AND_FITNESS`, secondary category is `LIFESTYLE`, age rating is `4+` with health/wellness topics disclosed and medical/treatment information set to `NONE`. Content rights are confirmed as `DOES_NOT_USE_THIRD_PARTY_CONTENT`. ASC privacy nutrition is published with 16 data-usage rows; readback returned `published: true` and `lastPublishedBy: J Mambwe`. RevenueCat server notifications are confirmed for production + sandbox, both `V2`. Subscription group `22150100`; special annual `6779256297` at `$29.99`, monthly `6779156238` at `$9.99`, annual `6779156833` at `$59.99`; annual has a 7-day free trial and review screenshots, while monthly and special annual have no intro trial. All subscriptions currently read `MISSING_METADATA`, so they still need to be submitted with the App Store version/build. App Review detail still needs a real contact phone number. ASC currently has zero uploaded iOS builds for this app. App Store availability remains blocked on ASC UI/API instability for this app route. |
| Google Play | Draft app/listing/subscriptions/app-content created | Ruvix Play app `4973846096696226350`, package `com.ruvixlabs.babyrelay`, title `BabyRelay: Shared Baby Care`. Listing metadata, support email, approved glow-face icon, and six shared-care phone screenshots are uploaded in draft. App content is caught up: privacy URL, ads, access, government, financial, health, content rating, target audience, and Data safety are saved. Play subscriptions are active: `babyrelay_pro_monthly` (`monthly`, `$9.99`, no active trial offer), `babyrelay_pro_annual` (`annual`, `$59.99`, 7-day trial), and `babyrelay_pro_special_annual` (`special-annual`, `$29.99`, no trial), all across `173` regions. Android upload signing, AAB/internal track upload, RTDN, and RevenueCat Android app/catalog wiring are still pending. |

## Build Defines

```bash
flutter build ios --release \
  --dart-define=FIREBASE_CONFIGURED=true \
  --dart-define=REVENUECAT_IOS_API_KEY=<from mc-vault: babyrelay-revenuecat-ios-sdk-key> \
  --dart-define=GLEAP_SDK_KEY=<from mc-vault> \
  --dart-define=APPREFER_LINK_ID=babyrelay-meta

flutter build apk --debug \
  --dart-define=FIREBASE_CONFIGURED=true \
  --dart-define=APPREFER_LINK_ID=babyrelay-meta
```

If a define is omitted, that service remains disabled and the app keeps its
local fallback behavior.

## Remaining Provider Work

| Follow-up | Needs | Where it lands |
|---|---|---|
| In-app two-device join smoke | Manual device/TestFlight session or simulator UI automation that can tap/type into Flutter | Backend client smoke has passed live Auth/Firestore rules against the optimized subcollection model. Still worth confirming the exact invite-code UI flow end to end in a running app. |
| Universal/deep links | Apple associated domains + web route for `babyrelay.app/join/<code>` | Join links open the app directly instead of only showing the code |
| RevenueCat sandbox purchase | TestFlight/sandbox build with the App Store SDK key | Validate current/special offerings and entitlement `pro` end to end |
| Android upload/release track | BabyRelay Android upload signing + first AAB internal track upload | Validate installable release artifact, Play signing, and publishing overview readiness |
| Android RevenueCat / RTDN | BabyRelay RevenueCat Android app, Android public SDK key, Play products imported, RTDN/Pub/Sub wired | Supply `REVENUECAT_ANDROID_API_KEY` and validate Android package fetching, purchase, restore, and entitlement `pro` |
| Remote sleep push fanout | Deploy updated Firestore rules + Cloud Functions with an approved Ruvix Firebase context; upload APNs Auth Key/capabilities in Apple/Firebase; TestFlight/physical iPhone remote-push smoke | Confirms owner sleep start/end wakes caregiver lock-screen Live Activity and Android ongoing notification without using the source device |
| AppStore Co-Pilot RevenueCat secret | BabyRelay RevenueCat secret API key created/stored | Enables AppStore Co-Pilot RevenueCat catalog tools for project `irq0wa833wWMRsASUxfK` |
| AppRefer redirect | Real App Store URL once the listing exists | `trk.apprefer.com` can redirect; optional future wrapping in `InviteService.decorateLink` |
| App Store assets/metadata | en-US launch metadata is documented in `docs/app-store-metadata.md` and reflected in AppStore Co-Pilot project `irq0wa833wWMRsASUxfK`. Privacy Policy is published at `https://appstorecopilot.com/legal/3omln7px/privacy`; Terms of Service is published at `https://appstorecopilot.com/legal/3omln7px/terms`; Support URL is `https://ruvixlabs.com`; all are linked or stored where appropriate. AppStore Co-Pilot compliance detects `hasSubscriptions: true` and currently returns zero issues. The approved no-paywall `gpt-image-2` v3 pop-out screenshots are staged in AppStore Co-Pilot and pushed to the editable ASC `1.0` version; ASC readback maps the accepted `1320x2868` frames to `APP_IPHONE_67`, six assets, all `COMPLETE`. Categories, age rating, content rights, and privacy nutrition are set. Still needs build selection/upload, review contact phone/details, App Store availability initialization, subscription attachment/submission, and final ASC publish. | AppStore Co-Pilot / ASC |

## Pre-submission checklist (when credentials exist)

1. Run a final in-app two-device UI smoke for invite-code entry. Backend
   anonymous Auth, invite-aware Firestore rules, join membership, optimized
   shared event doc write/read, and cleanup passed live on 2026-06-22.
2. Upload an App Store/TestFlight build, add the required ASC App Review
   contact phone number, and initialize App Store availability once the
   BabyRelay ASC route stops returning shell-only/500 states.
3. Run a RevenueCat sandbox purchase and restore with the live App Store
   offering.
4. Run `flutter analyze` + `flutter test`; full `app-presubmission` skill.
5. Verify free-tier gates (2nd child, 3rd caregiver) against App Review
   guidelines with the live paywall.
