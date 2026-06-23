# App Store Privacy Nutrition Worksheet

This is the working App Store Connect App Privacy answer set for BabyRelay.
It is based on the shipped Flutter code, Firebase/RevenueCat/Gleap/AppRefer
SDKs, `docs/privacy-policy.md`, and the Google Play Data Safety declaration
saved on 2026-06-23.

ASC status on 2026-06-23: the visual App Privacy route did not render in the
Ruvix browser profile, and `asc web privacy` needs a separate cached Apple web
session. Use this worksheet when the ASC App Privacy UI is reachable again.

## App-Level Answers

- The app collects data: **Yes**.
- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes**.
- Privacy Policy URL: `https://appstorecopilot.com/legal/3omln7px/privacy`
- Privacy Choices URL: leave blank unless a dedicated choices page is created.

## Data Types To Declare

| Apple data type | Collected | Linked to user | Tracking | Purposes |
|---|---:|---:|---:|---|
| Contact Info - Name | Yes | Yes | No | App Functionality |
| Contact Info - Email Address | Yes, optional via support/contact flows | Yes | No | App Functionality, Developer Communications |
| Health & Fitness - Health | Yes | Yes | No | App Functionality, Product Personalization |
| User Content - Other User Content | Yes | Yes | No | App Functionality |
| Purchases - Purchase History | Yes | Yes | No | App Functionality, Account Management |
| Identifiers - User ID | Yes | Yes | No | App Functionality, Analytics, Fraud Prevention/Security, Account Management |
| Identifiers - Device ID | Yes | Yes | Yes when ATT/AppRefer attribution is enabled and authorized | App Functionality, Analytics, Developer Advertising or Marketing, Fraud Prevention/Security |
| Usage Data - Product Interaction | Yes | Yes | No | Analytics |
| Diagnostics - Crash Data | Yes | Yes | No | Analytics |
| Diagnostics - Performance Data / Other Diagnostic Data | Yes | Yes | No | Analytics |

## Rationale

- BabyRelay stores child nicknames, caregiver names/roles, care events, notes,
  feeds, diapers, sleep/wake events, invite membership, and handoff context in
  Firebase/Firestore for shared baby care. This should be represented as
  `Health` and `Other User Content`, linked to the family/user.
- Firebase Auth currently signs users in anonymously, but the Firebase UID is a
  user identifier and is used for membership, Firestore rules, analytics, and
  sync.
- Firebase Analytics sends only allowlisted events with enum-like parameters;
  no child names, caregiver names, free-text notes, or exact health details are
  logged.
- Firebase Crashlytics and diagnostics are used for reliability.
- RevenueCat collects purchase history/subscription state and app user
  identifiers for entitlement management.
- Gleap may collect support contact details and diagnostic/support conversation
  details when a user contacts support.
- AppRefer/ATT attribution means device/advertising identifiers may be used for
  campaign attribution. Treat Device ID as tracking when ATT authorization and
  attribution are enabled.

## Do Not Declare Unless The App Changes

- Location
- Contacts
- Search History
- Browsing History
- Sensitive Info beyond the Health category above
- Financial information beyond purchase history
- Contact list
- Photos, videos, audio, gameplay content, or environment scanning

## Entry Notes

- Be conservative for review: if Apple asks whether data is linked to users,
  answer **Yes** for the declared data types because family data and analytics
  are tied to Firebase/RevenueCat/Gleap identifiers.
- Do not claim `Data Not Collected`; BabyRelay is a shared-care app and
  necessarily collects family care data.
- If AppRefer attribution is disabled for the submitted build, revisit the
  `Device ID` tracking row before final submission.
