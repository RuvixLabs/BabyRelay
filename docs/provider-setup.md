# Provider Setup

Last updated: 2026-06-22

## Firebase

- Company: Ruvix Labs
- Firebase/GCP project ID: `babyrelay-ruvix`
- iOS bundle ID: `com.ruvixlabs.babyrelay`
- Firebase iOS app ID: `1:500197010265:ios:3e9e3b96b065cb7b287a48`
- Firebase Web app ID: `1:500197010265:web:d6c4297117240e90287a48`
- Firestore database: `(default)`, Firestore Native, `nam5`
- Local config: `ios/Runner/GoogleService-Info.plist`

Enabled services include Firebase Management, Firestore, Firebase Auth
(`identitytoolkit`), Crashlytics, FCM, App Check, Installations, and Remote
Config.

Live sync state:

- Anonymous Auth is enabled for `babyrelay-ruvix`. This was provisioned through
  the Ruvix-authenticated Firebase Management API after the first live smoke
  returned `CONFIGURATION_NOT_FOUND`.
- Firestore rules are deployed to the `cloud.firestore` release:
  `557fed9a-ba93-4639-815c-c5a3dd594abb`.
- A client-side live smoke passed on 2026-06-22 using two anonymous users and
  no admin bypass:
  - owner anonymous Auth token issued
  - owner created a family document
  - owner created an invite code document
  - joiner read the family through the invite-code rule before membership
  - joiner joined the family through invite-aware rules
  - owner wrote a shared care event after join
  - joiner read the owner-written shared event
  - smoke invite/family cleanup completed
- The Firebase CLI is not logged in as `joe@ruvixlabs.com` in this worker pane,
  so Auth provisioning and rules deployment were done with the Ruvix gcloud
  context plus Firebase/Rules REST APIs. Future CLI deploys should explicitly
  select the Ruvix context before mutating live Firebase state.

## AppRefer

- Company/org: Ruvix Labs
- Org ID: `Y0dj51pp63wBS2NN4ZdY`
- App ID: `app_16e4ca28f81`
- Bundle ID: `com.ruvixlabs.babyrelay`
- Default Meta link ID: `babyrelay-meta`
- SDK key vault services:
  - `babyrelay-apprefer-api-key`
  - `babyrelay-apprefer-test-api-key`

`https://apprefer.com/api/c/babyrelay-meta` returns the AppRefer capture page.
`https://trk.apprefer.com/api/c/babyrelay-meta` will return 404 until the app
has a real store destination URL, because the tracking host cannot redirect
without an App Store / Play destination.

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
- Terms of Service is published through AppStore Co-Pilot:
  `https://appstorecopilot.com/legal/3omln7px/terms`. The URL returns `200`
  and is linked from the app paywall and Settings.
- Subscription catalog is synced from live ASC into AppStore Co-Pilot:
  - Group: `22150100`, `BabyRelay Family`
  - Monthly: `6779156238`, `babyrelay_pro_monthly`, `$9.99`, 7-day
    free trial in `175` territories
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
  The six stored AppStore Co-Pilot URLs were read back with HTTP 200. The set
  has not been pushed to App Store Connect yet.

## App Store Connect

- Ruvix bundle ID: `7PA3RQ369P`
- Bundle identifier: `com.ruvixlabs.babyrelay`
- In-App Purchase capability: enabled
- ASC app ID: `6779147183`
- ASC app name: `BabyRelay : Shared Baby Care`
- ASC SKU: `BabyRelay`
- Apple server notifications: live ASC readback on 2026-06-16 shows
  production and sandbox notification URLs are not currently set. RevenueCat
  still has the server-to-server notification token, but the production/sandbox
  V2 URLs must be re-applied in App Store Connect before submission.
- Subscription group: `22150100`, `BabyRelay Family`, localized `en-US`
- Subscriptions:
  - Special annual: `6779256297`, product ID
    `babyrelay_pro_special_annual`, period `ONE_YEAR`, USA price `$29.99`,
    no free trial, available in `50` territories
  - Monthly: `6779156238`, product ID `babyrelay_pro_monthly`, period
    `ONE_MONTH`, USA price `$9.99`, 7-day free trial in `175` territories
  - Annual: `6779156833`, product ID `babyrelay_pro_annual`, period
    `ONE_YEAR`, USA price `$59.99`, 7-day free trial in `175` territories
- Review screenshot: `artifacts/app_store_review/babyrelay_paywall_review.png`
  captured from the real Flutter paywall at `1206x2622`. The current screenshot
  includes the visible launch-offer timer and is uploaded to all three
  subscriptions:
  - Special annual: `e0323cd6-0cc3-4f4f-b936-feee23f629c8`
  - Annual: `e66325c4-9dec-4025-8bcd-491eeafd5755`
  - Monthly: `4eecee8b-68a0-4c29-9fb5-39bf4b6943f3`
- Current ASC product state: all subscriptions still read back
  `MISSING_METADATA`. Product localization, pricing, availability, free trials,
  group localization, and review screenshots are present; first-time
  subscriptions still need to travel with the App Store version submission, not
  standalone submission.

Remaining App Store / subscription blockers:

- Build with `babyrelay-revenuecat-ios-sdk-key` and run a sandbox purchase
  smoke against the real offering.
- Create/store a BabyRelay RevenueCat secret API key if AppStore Co-Pilot needs
  direct RevenueCat catalog management.
- Submit the subscriptions with the App Store version and a build; do not use a
  standalone subscription submission path for first-time products.
- Wire AppRefer purchase forwarding via RevenueCat webhook for sandbox and
  production events.

## App code wiring

- Firebase SDK packages are installed. `main.dart` initializes Firebase,
  Crashlytics, Analytics, Messaging, anonymous Auth, and Firestore sync when
  `--dart-define=FIREBASE_CONFIGURED=true` is present.
- Firestore rules are committed in `firestore.rules` and deployed to the
  `cloud.firestore` release on `babyrelay-ruvix` as ruleset
  `557fed9a-ba93-4639-815c-c5a3dd594abb`.
- RevenueCat SDK is installed. `RevenueCatPurchaseService` reads current and
  `special_offer` offerings, maps the three App Store product IDs, and unlocks
  entitlement `pro`.
- Gleap SDK is installed. Settings opens in-app support when
  `GLEAP_SDK_KEY` is supplied, otherwise it falls back to the support email.
- App tracking transparency is installed. `APPREFER_LINK_ID=babyrelay-meta`
  enables the ATT request seam; AppRefer redirecting still needs the live store
  destination URL.
