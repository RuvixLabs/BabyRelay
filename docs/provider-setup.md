# Provider Setup

Last updated: 2026-06-10

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
- Login vault services:
  - `babyrelay-revenuecat-username`
  - `babyrelay-revenuecat-password`
- RevenueCat webhook secret vault service:
  - `babyrelay-apprefer-revenuecat-webhook-secret`

Signup was submitted successfully and reached RevenueCat's `/welcome` flow, but
dashboard/project onboarding is still blocked by RevenueCat's post-signup login
state. A Gmail search found other RevenueCat verification/welcome emails from
the same day, but found no BabyRelay email to `joe+babyrelay@ruvixlabs.com`.
Treat the account as incomplete until that alias/email delivery issue is cleared
or a receiving Ruvix address is chosen. The next RevenueCat pass should create:

- Project: `BabyRelay`
- iOS app bundle: `com.ruvixlabs.babyrelay`
- Entitlement: `pro`
- Products: `babyrelay_pro_monthly`, `babyrelay_pro_annual`
- Default offering/package mapping for the two products
- AppRefer RevenueCat webhook integration for sandbox and production events
