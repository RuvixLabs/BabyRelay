# Provider Setup

Last updated: 2026-06-11

## Firebase

- Company: Ruvix Labs
- Firebase/GCP project ID: `babyrelay-ruvix`
- iOS bundle ID: `com.ruvixlabs.babyrelay`
- Firebase iOS app ID: `1:500197010265:ios:3e9e3b96b065cb7b287a48`
- Firestore database: `(default)`, Firestore Native, `nam5`
- Local config: `ios/Runner/GoogleService-Info.plist`

Enabled services include Firebase Management, Firestore, Firebase Auth
(`identitytoolkit`), Crashlytics, FCM, App Check, Installations, and Remote
Config.

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

## App Store Connect

- Ruvix bundle ID: `7PA3RQ369P`
- Bundle identifier: `com.ruvixlabs.babyrelay`
- In-App Purchase capability: enabled
- ASC app ID: `6779147183`
- ASC app name: `BabyRelay : Shared Baby Care`
- ASC SKU: `BabyRelay`
- Apple server notifications: production and sandbox URLs are set from
  RevenueCat, both read back as version `V2`.
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

- Implement the RevenueCat-backed `PurchaseService` and build with
  `babyrelay-revenuecat-ios-sdk-key`.
- Submit the subscriptions with the App Store version and a build; do not use a
  standalone subscription submission path for first-time products.
- Run a sandbox purchase smoke after the build can fetch the real RevenueCat
  offering.
- Wire AppRefer purchase forwarding via RevenueCat webhook for sandbox and
  production events.
