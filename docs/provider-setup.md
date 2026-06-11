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
  - `babyrelay_pro_monthly` (`P1M`)
  - `babyrelay_pro_annual` (`P1Y`)
- Default offering: `default`
- Packages:
  - `$rc_monthly` -> `babyrelay_pro_monthly`
  - `$rc_annual` -> `babyrelay_pro_annual`
- No lifetime product is active.

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
- Subscription groups: none yet (`0` groups read back from ASC).

Remaining App Store / subscription blockers:

- Create App Store subscription products matching the RevenueCat product IDs:
  `babyrelay_pro_monthly` and `babyrelay_pro_annual`.
- Move the app build from the Test Store SDK key to
  `babyrelay-revenuecat-ios-sdk-key` once the real store products exist.
- Wire AppRefer purchase forwarding via RevenueCat webhook for sandbox and
  production events.
