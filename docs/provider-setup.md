# Provider Setup

Last updated: 2026-07-09

## Firebase

- Company: Ruvix Labs
- Firebase/GCP project ID: `babyrelay-ruvix`
- iOS bundle ID: `com.ruvixlabs.babyrelay`
- Android package name: `com.ruvixlabs.babyrelay`
- Firebase iOS app ID: `1:500197010265:ios:3e9e3b96b065cb7b287a48`
- Firebase Android app ID: `1:500197010265:android:cf90d1f6dc5b788a287a48`
- Firebase Web app ID: `1:500197010265:web:d6c4297117240e90287a48`
- Firestore database: `(default)`, Firestore Native, `nam5`
- Local configs:
  - `ios/Runner/GoogleService-Info.plist`
  - `android/app/google-services.json`

Enabled services include Firebase Management, Firestore, Firebase Auth
(`identitytoolkit`), Crashlytics, FCM, App Check, Installations, Remote
Config, Cloud Functions, Cloud Run, Cloud Build, Eventarc, Artifact Registry,
and Pub/Sub.

Live sync state:

- Anonymous Auth is enabled for `babyrelay-ruvix`. This was provisioned through
  the Ruvix-authenticated Firebase Management API after the first live smoke
  returned `CONFIGURATION_NOT_FOUND`.
- Firestore rules are deployed to the `cloud.firestore` release:
  `22a5e94c-4d73-433e-a5d5-d71b9537f7f3`.
- Cloud Function `onSleepEventWritten` is deployed as a Gen 2 function in
  `us-central1`, runtime `nodejs22`, revision
  `onsleepeventwritten-00003-pon`, with Eventarc trigger
  `projects/babyrelay-ruvix/locations/nam5/triggers/onsleepeventwritten-372265`
  on Firestore `(default)` writes matching
  `families/{familyId}/events/{eventId}`.
- On 2026-07-09, the registered Ruvix Firebase profile was authenticated as
  `joe@ruvixlabs.com`. The historical Ruvix APNs auth key was capability-proved
  without exposing it and uploaded to both the development and production FCM
  slots for iOS app `1:500197010265:ios:3e9e3b96b065cb7b287a48`.
- A client-side optimized-subcollection live smoke passed on 2026-06-22 using
  two anonymous users and no admin bypass:
  - owner anonymous Auth token issued
  - owner created a small family metadata document
  - owner created child and caregiver subcollection documents
  - owner created an invite code document
  - joiner read the family through the invite-code rule before membership
  - joiner joined the family through invite-aware rules
  - owner wrote one shared care event document after join
  - joiner read the owner-written shared event
  - smoke invite/family cleanup completed
- A remote-sleep backend live smoke passed on 2026-07-07 after the Functions
  deploy using two fresh anonymous users and no admin bypass:
  - owner created a synthetic family, child, invite code, owner device, and
    ongoing sleep event with `loggedByDeviceId`
  - caregiver read the family by invite before membership, joined through the
    invite-aware update rule, wrote its own private device token document, and
    read the owner-written sleep event
  - owner was denied reading the caregiver's private device doc
  - deployed `onSleepEventWritten` produced a successful Cloud Run request
    (`200`) after the sleep write
  - synthetic family and invite docs read back `404` after cleanup
- A two-user release smoke passed on 2026-07-09 after the hardened rules and
  revision `00003` deploy, again using client Auth tokens and no admin bypass:
  - owner and caregiver joined through the live invite flow
  - caregiver listed its own device and ActivityKit activity subcollections
  - caregiver deleted its own caregiver document and self-removed from the
    family while the owner remained
  - post-leave access to the member-only sleep event returned `403`
  - the sleep create/delete produced two revision `00003` Cloud Run requests,
    both `200`
  - all synthetic documents and Auth users were cleaned up
- The Firebase CLI is not logged in as `joe@ruvixlabs.com` in this worker pane,
  so Auth provisioning/rules deployment use the Ruvix gcloud context plus
  Firebase/Rules REST APIs. The 2026-07-09 Functions deploy used
  `gcloud functions deploy` with the explicit `ruvix-labs` configuration,
  project, trigger, service accounts, limits, and no-retry policy.
  Future CLI deploys should explicitly select the Ruvix context before mutating
  live Firebase state.

## AppRefer

- Company/org: Ruvix Labs
- Org ID: `Y0dj51pp63wBS2NN4ZdY`
- App ID: `app_16e4ca28f81`
- Bundle ID: `com.ruvixlabs.babyrelay`
- Default Meta link ID: `babyrelay-meta`
- SDK key vault services:
  - `babyrelay-apprefer-api-key`
  - `babyrelay-apprefer-test-api-key`
- SDK enabled: `true`
- Store destinations:
  - iOS: `https://apps.apple.com/app/id6779147183`
  - Android: `https://play.google.com/store/apps/details?id=com.ruvixlabs.babyrelay`
- RevenueCat integration: `connected=true`

`https://apprefer.com/api/c/babyrelay-meta` returns the AppRefer capture page.
The AppRefer foundation is configured. Release proof still requires a real
paid click through install/open and a matching RevenueCat purchase readback.

## RevenueCat

- Account email: `joe+babyrelay@ruvixlabs.com`
- Project ID: `26c4f023`
- Project name: `BabyRelay`
- Login vault services:
  - `babyrelay-revenuecat-username`
  - `babyrelay-revenuecat-password`
- Test Store public SDK key vault service:
  - `babyrelay-revenuecat-test-sdk-key`
- App Store public SDK key vault service:
  - `babyrelay-revenuecat-ios-sdk-key`
- RevenueCat webhook secret vault service:
  - `babyrelay-apprefer-revenuecat-webhook-secret`

Dashboard login is now unblocked. The RevenueCat account still shows an
unconfirmed-email banner and should be confirmed through the dashboard resend
flow, but that is not blocking catalog edits.

Live RevenueCat readback:

- Test Store app: `appf68d685da8`
- App Store app: `app70e3a91be4`
  - Name: `BabyRelay (App Store)`
  - Bundle ID: `com.ruvixlabs.babyrelay`
  - In-app purchase key: configured with Ruvix key ID `9CYKZWD35Y`
  - App Store Connect API key: configured with Ruvix key ID `D88WNB6D69`
  - Server-to-server notification token exists in RevenueCat
- Active entitlement: `pro`
- AppRefer webhook: `whintgr70a141be8d`, enabled, scoped to
  `BabyRelay (App Store)`, all events, production + sandbox. It points to the
  per-app AppRefer RevenueCat endpoint, uses the vaulted authorization secret,
  and returned `Response 200` in the RevenueCat test tool on 2026-07-09.
- Products:
  - `babyrelay_pro_special_annual` (`P1Y`, App Store special offer)
  - `babyrelay_pro_monthly` (`P1M`)
  - `babyrelay_pro_annual` (`P1Y`)
- Default offering: `default`
- Packages:
  - `$rc_monthly` -> Test Store `babyrelay_pro_monthly` and App Store
    `babyrelay_pro_monthly`
  - `$rc_annual` -> Test Store `babyrelay_pro_annual` and App Store
    `babyrelay_pro_annual`
- Special offer offering: `special_offer` (`ofrngdfa887bf9a`), not current
  - Metadata: `title=Special Offer`, `badge_text=BEST VALUE`,
    `countdown_seconds=90`
  - `special_annual` package (`pkge0daa9fb60f`) -> App Store
    `babyrelay_pro_special_annual`
- No lifetime product is active.
- App Store products imported into RevenueCat:
  - Special annual: `prod43e81fc3ea`, `babyrelay_pro_special_annual`, attached
    to `pro`
  - Monthly: `prod7eca500296`, `babyrelay_pro_monthly`, attached to `pro`
  - Annual: `prod5e1be41b9d`, `babyrelay_pro_annual`, attached to `pro`
- Google Play products now exist in the Ruvix Play app, but they are not yet
  imported into RevenueCat because the BabyRelay RevenueCat Android app and
  public SDK key still need to be created from the BabyRelay-specific RevenueCat
  account. The app code accepts a platform-specific Android public SDK key
  through `--dart-define=REVENUECAT_ANDROID_API_KEY=...`, and it tolerates
  Google Play product identifiers that include a base-plan suffix
  (`productId:basePlanId`).

RevenueCat initially created an accidental entitlement identifier
`BabyRelay Pro`; the two products were moved to `pro`, and the accidental
entitlement is archived with no products attached.

## AppStore Co-Pilot

- Owner: Ruvix user `joe@ruvixlabs.com`
- Owner user ID: `GK524x5pDvUn8E55SSc6obfimjZ2`
- Project ID: `irq0wa833wWMRsASUxfK`
- Project name: `BabyRelay : Shared Baby Care`
- Store type: `ios`
- App Store app ID: `6779147183`
- Primary locale: `en-US`

Live AppStore Co-Pilot readback:

- Project exists at
  `users/GK524x5pDvUn8E55SSc6obfimjZ2/projects/irq0wa833wWMRsASUxfK`.
- Ruvix account-level App Store credentials are present in AppStore Co-Pilot,
  so the project can use the same credential inheritance model as the other
  Ruvix iOS apps.
- Firebase IDs are linked:
  - Firebase project ID: `babyrelay-ruvix`
  - Firebase iOS app ID: `1:500197010265:ios:3e9e3b96b065cb7b287a48`
- RevenueCat project ID is linked: `26c4f023`.
- en-US launch metadata is staged as AppStore Co-Pilot metadata history
  version 7. The repo copy is `docs/app-store-metadata.md`. Latest
  AppStore Co-Pilot compliance result has zero metadata-copy warnings.
- Privacy Policy is published through AppStore Co-Pilot:
  `https://appstorecopilot.com/legal/3omln7px/privacy`. The URL returns `200`
  and is stored on both the project and en-US metadata record.
- Support URL is stored on the AppStore Co-Pilot en-US metadata record as
  `https://ruvixlabs.com`.
- Terms of Service is published through AppStore Co-Pilot:
  `https://appstorecopilot.com/legal/3omln7px/terms`. The URL returns `200`
  and is linked from the app paywall and Settings.
- Subscription catalog is synced from live ASC into AppStore Co-Pilot:
  - Group: `22150100`, `BabyRelay Family`
  - Monthly: `6779156238`, `babyrelay_pro_monthly`, `$9.99`, no intro trial
  - Annual: `6779156833`, `babyrelay_pro_annual`, `$59.99`, 7-day
    free trial in `175` territories
  - Special annual: `6779256297`, `babyrelay_pro_special_annual`, `$29.99`,
    no intro trial
- AppStore Co-Pilot compliance now detects `hasSubscriptions: true` /
  `hasPaidContent: true` and returns zero issues after the Terms of Service
  publication.
- RevenueCat public SDK keys are in `mc-vault`, but no BabyRelay RevenueCat
  secret API key is stored yet. AppStore Co-Pilot's RevenueCat management tools
  will need a `babyrelay-revenuecat-secret-key` vault entry and project field
  before they can manage/read the RevenueCat catalog directly.
- The approved GPT-image-2 v3 App Store screenshot set is staged in
  AppStore Co-Pilot for `APP_IPHONE_69` / `en-US` with `syncStatus:
  local_changes`:
  `artifacts/app_store_screenshots/gpt-image-2-story-v3-popouts/2026-06-16/iphone_69/`.
  The six stored AppStore Co-Pilot URLs were read back with HTTP 200. The same
  approved set has also been pushed to the editable App Store Connect `1.0`
  version; ASC readback maps the accepted `1320x2868` frames to display type
  `APP_IPHONE_67`, with all six screenshot assets in `COMPLETE` delivery state.

## App Store Connect

- Ruvix bundle ID: `7PA3RQ369P`
- Bundle identifier: `com.ruvixlabs.babyrelay`
- Enabled bundle capabilities:
  - `IN_APP_PURCHASE`
  - `PUSH_NOTIFICATIONS` (enabled through the Ruvix ASC API on 2026-07-07)
- Firebase App Distribution ad hoc profile:
  - Old profile `RM7Y2M2HC3` / `BabyRelay Firebase Ad Hoc 2026-06-17` became
    `INVALID` after push capability was enabled.
  - Replacement profile `38C6N549R4` / `BabyRelay Firebase Ad Hoc 2026-07-07
    Push` is `ACTIVE`, uses team `S399W94VV8`, contains 27 devices including
    Joe's iPhone 15, and includes `aps-environment=production`.
  - Installed locally at
    `~/Library/MobileDevice/Provisioning Profiles/d7cff848-2931-4533-9e19-833e446f7a59.mobileprovision`.
  - `ios/ExportOptions-Firebase.plist` points Firebase App Distribution exports
    at this replacement profile.
- ASC app ID: `6779147183`
- ASC app name: `BabyRelay : Shared Baby Care`
- ASC SKU: `BabyRelay`
- Editable app version: `1.0`, state `PREPARE_FOR_SUBMISSION`
- en-US live metadata pushed on 2026-06-23:
  - App name: `BabyRelay: Shared Baby Care`
  - Subtitle: `Baby Log & Care Sync`
  - Privacy Policy URL:
    `https://appstorecopilot.com/legal/3omln7px/privacy`
  - Description, keywords, promotional text, and Support URL
    `https://ruvixlabs.com`
  - `What's New` is intentionally skipped for the first live version.
- Categories:
  - Primary: `HEALTH_AND_FITNESS`
  - Secondary: `LIFESTYLE`
- Age rating declaration:
  - App Store age rating: `4+`
  - Health or wellness topics: `true`
  - Medical/treatment information: `NONE`
  - Unrestricted web access, user-generated content, messaging/chat,
    advertising, gambling, and loot boxes: `false`
  - Developer age-rating info URL: `https://ruvixlabs.com`
- App Store screenshots pushed on 2026-06-23:
  - Version localization: `en-US`
  - Source set:
    `artifacts/app_store_screenshots/gpt-image-2-story-v3-popouts/2026-06-16/iphone_69/final/`
  - ASC screenshot set: `APP_IPHONE_67`
  - Count: `6`
  - Dimensions: `1320x2868`
  - Delivery state: all `COMPLETE`
- Export compliance: `ios/Runner/Info.plist` declares
  `ITSAppUsesNonExemptEncryption=false` because the app uses standard
  platform/network encryption only.
- Content rights: confirmed in ASC on 2026-06-23 as
  `DOES_NOT_USE_THIRD_PARTY_CONTENT` using `asc apps update` and
  `asc apps content-rights view`.
- App Review detail: the established real Ruvix review contact is saved, with
  BabyRelay-specific review notes. Contact details are intentionally not copied
  into this repository.
- App availability: initialized on 2026-07-09 for all 175 territories, with new
  territories enabled and no pre-order. The previous Apple route/API blocker is
  cleared.
- App price: free, initialized in the app price schedule.
- Signed build `1.0 (3)`:
  - Build ID: `59a88169-b775-4a97-aa98-50977cbccaad`
  - Processing state: `VALID`
  - Attached to App Store version `1.0`
  - TestFlight state: `IN_BETA_TESTING` in `BabyRelay Internal`
  - TestFlight contact and en-US What to Test notes are complete; validator has
    zero errors, warnings, or blockers.
- Browser / web-session state: the registered Ruvix ASC profile currently lands
  on Apple sign-in and verifies with `mutation_allowed=false`. Reauthenticate
  that same registered profile before completing the regulated-medical-device
  declaration or first-time subscription selection; do not substitute another
  company or normal Chrome profile. Earlier authenticated readback already
  proved the live metadata, screenshots, Support URL, App Review fields,
  privacy nutrition, and pricing/availability state.
- App Privacy / privacy nutrition: completed on 2026-06-23 through the
  authenticated browser's Iris endpoints because the visual App Privacy pane did
  not render and `asc web privacy` had no cached Apple web session. ASC readback
  returned 16 declared data-usage rows and `published: true` with
  `lastPublishedBy: J Mambwe`. The published answer set is documented in
  `docs/app-store-privacy-nutrition.md`.
- Apple server notifications: confirmed in ASC on 2026-06-23 via explicit
  app-field readback. Production and sandbox RevenueCat notification URLs are
  both present and both use `V2`. Do not print or commit the full notification
  URLs; derive them from RevenueCat app settings when needed.
- Subscription group: `22150100`, `BabyRelay Family`, localized `en-US`
- Subscriptions:
  - Special annual: `6779256297`, product ID
    `babyrelay_pro_special_annual`, period `ONE_YEAR`, USA price `$29.99`,
    no free trial, available and priced in `175` territories
  - Monthly: `6779156238`, product ID `babyrelay_pro_monthly`, period
    `ONE_MONTH`, USA price `$9.99`, no intro trial, available and priced in
    `175` territories
  - Annual: `6779156833`, product ID `babyrelay_pro_annual`, period
    `ONE_YEAR`, USA price `$59.99`, 7-day free trial, available and priced in
    `175` territories
- Review screenshot: `artifacts/app_store_review/babyrelay_paywall_review.png`
  captured from the real Flutter paywall at `1206x2622`. The uploaded screenshot
  includes the visible launch-offer timer and shows Monthly without a trial
  badge, but it predates the 2026-06-23 support-copy cleanup that changed
  "start with a trial" to "annual trial, or monthly plan"; refresh it before
  final ASC submission. It is uploaded to all three subscriptions:
  - Special annual: `e0323cd6-0cc3-4f4f-b936-feee23f629c8`
  - Annual: `e66325c4-9dec-4025-8bcd-491eeafd5755`
  - Monthly: `4eecee8b-68a0-4c29-9fb5-39bf4b6943f3`
- Current ASC product state: all three subscriptions read `READY_TO_SUBMIT`.
  They must be selected on App Store version 1.0 and travel with that first app
  submission, not through a standalone subscription submission.

## Google Play / Android

- Android package name: `com.ruvixlabs.babyrelay`
- Native Android project: `android/`
- Firebase Android app ID:
  `1:500197010265:android:cf90d1f6dc5b788a287a48`
- Firebase config: `android/app/google-services.json`
- Play Console developer: Ruvix Ltd, developer ID `7730130263000890927`
- Play Console app ID: `4973846096696226350`
- Play app name: `BabyRelay: Shared Baby Care`
- Play app type/pricing: App, free, en-US primary locale
- Launcher icon: generated from the approved Android-safe glow-face source,
  with legacy density icons, adaptive foreground layers, `ic_launcher.xml`,
  `ic_launcher_round.xml`, and background color `#071537`.
- Build status: `flutter build apk --debug --dart-define=FIREBASE_CONFIGURED=true
  --dart-define=APPREFER_LINK_ID=babyrelay-meta` passed on 2026-06-23.
- Advertising ID status: Play declaration is "No." The Android manifest removes
  both `com.google.android.gms.permission.AD_ID` and
  `android.permission.ACCESS_ADSERVICES_AD_ID` with `tools:node="remove"` so
  Firebase/measurement transitive permissions do not land in the merged app
  manifest.
- Device smoke: installed and launched on Android device `SM G973F`
  (`RF8MC08242T`, Android 11). First Flutter frame appeared after the native
  splash; logcat showed Firebase/Crashlytics initialization and no fatal
  exception/ANR.
- Play listing draft:
  - Title: `BabyRelay: Shared Baby Care`
  - Short description: `Shared baby logs, sleep guidance, and care handoffs for
    every caregiver.`
  - Full description: synced from the approved App Store metadata
  - Support email: `support@ruvixlabs.com`
  - App icon: approved glow-face Play icon uploaded
  - Phone screenshots: six approved shared-care screenshots uploaded for
    `en-US`
- Play App content is caught up:
  - Privacy Policy URL:
    `https://appstorecopilot.com/legal/3omln7px/privacy`
  - Ads: no ads
  - App access: no special restricted access
  - Government apps: no
  - Financial features: no financial features
  - Health apps: sleep management
  - Content rating: ESRB `Everyone`, PEGI `3`, USK `All ages`, generic `3+`;
    interactive elements disclose `Users Interact` and `In-App Purchases`
  - Target audience: `18 and over`
  - Data safety: shared baby-care data, purchases, app activity, diagnostics,
    and device IDs disclosed; encrypted in transit; deletion request URL points
    to the published Privacy Policy
- Play subscriptions/base plans:
  - Monthly: `babyrelay_pro_monthly`, base plan `monthly`, period `P1M`, USA
    price `$9.99`, active, no active trial offer, `173` regions
  - Annual: `babyrelay_pro_annual`, base plan `annual`, period `P1Y`, USA
    price `$59.99`, active, 7-day trial offer `trial-7-day`, `173` regions
  - Special annual: `babyrelay_pro_special_annual`, base plan
    `special-annual`, period `P1Y`, USA price `$29.99`, active, no trial,
    `173` regions

Remaining Android / Play blockers:

- Create Android upload signing for BabyRelay; do not reuse the ThreadCam
  keystore.
- Create/configure the RevenueCat Android app, store its Android public SDK key
  in `mc-vault`, attach Google Play products to entitlement `pro`, and wire
  Google Play RTDN/Pub/Sub to RevenueCat before production submission.
- Upload an Android App Bundle to an internal track, run install/purchase smoke,
  then complete the production release/publishing overview path.

Remaining App Store / subscription blockers:

- Reauthenticate the registered Ruvix ASC browser profile and set the web-only
  regulated medical device declaration to `No`.
- Select all three first-time subscriptions on version 1.0 and add the version
  to the existing draft review submission.
- Run sandbox purchase/restore on TestFlight build `1.0 (3)` against the real
  offering.
- Create/store a BabyRelay RevenueCat secret API key if AppStore Co-Pilot needs
  direct RevenueCat catalog management.
- Do not press final Submit until the physical two-device remote Live Activity
  and sandbox purchase/restore checks pass.

## App code wiring

- Firebase SDK packages are installed. `main.dart` initializes Firebase,
  Crashlytics, Analytics, Messaging, anonymous Auth, and Firestore sync when
  `--dart-define=FIREBASE_CONFIGURED=true` is present.
- Firestore rules are committed in `firestore.rules` and deployed to the
  `cloud.firestore` release on `babyrelay-ruvix` as ruleset
  `22a5e94c-4d73-433e-a5d5-d71b9537f7f3`.
- Cloud Function `onSleepEventWritten` is deployed on Node.js 22 and fans out
  Firestore sleep event writes to family devices through FCM / ActivityKit
  payloads. Backend smoke has verified rules, token-doc writes, trigger
  invocation, and cleanup; a real APNs/FCM delivery smoke still needs physical
  or TestFlight devices with valid push tokens.
- RevenueCat SDK is installed. `RevenueCatPurchaseService` reads current and
  `special_offer` offerings, maps the three App Store product IDs, and unlocks
  entitlement `pro`. Purchase/restore marks the shared family subscription
  active so paid capacity gates apply to the family and join-by-code can accept
  over-free-limit caregivers for a subscribed family. Platform-specific keys
  are preferred: `REVENUECAT_IOS_API_KEY` and
  `REVENUECAT_ANDROID_API_KEY`; the old `REVENUECAT_API_KEY` define remains a
  fallback for local/testing builds.
- Gleap SDK is installed. Settings opens in-app support when
  `GLEAP_SDK_KEY` is supplied, otherwise it falls back to the support email.
- App tracking transparency and AppRefer SDK `0.4.1` are installed. A release
  build requires the live `APPREFER_API_KEY`; the SDK initializes only after the
  first-visible-launch ATT path and bridges `appreferId` into RevenueCat.
  `APPREFER_LINK_ID=babyrelay-meta` remains the caregiver-link identifier, and
  canonical iOS and Android store destinations plus RevenueCat server
  forwarding are configured. A real paid click/install/purchase proof remains.
