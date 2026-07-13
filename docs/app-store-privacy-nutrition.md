# App Store Privacy Nutrition Worksheet

This is the working App Store Connect App Privacy answer set for BabyRelay.
It is based on the shipped Flutter code, Firebase/Superwall/Gleap/AppRefer
SDKs, `docs/privacy-policy.md`, and the Google Play Data Safety declaration
saved on 2026-06-23.

ASC status on 2026-06-23: the visual App Privacy route did not render in the
Ruvix browser profile, and `asc web privacy` had no separate cached Apple web
session. The authenticated browser session was able to call the same Iris
privacy endpoints used by the ASC UI. The declaration below was created and
published in ASC on 2026-06-23; readback returned `published: true`,
`lastPublished: 2026-06-23T07:39:40-07:00`, and
`lastPublishedBy: J Mambwe`.

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
| Contact Info - Email Address | Yes, optional via support/contact flows | Yes | No | App Functionality |
| Health & Fitness - Health | Yes | Yes | No | App Functionality, Product Personalization |
| User Content - Other User Content | Yes | Yes | No | App Functionality |
| Purchases - Purchase History | Yes | Yes | No | App Functionality, Account Management |
| Identifiers - User ID | Yes | Yes | No | App Functionality, Analytics, Fraud Prevention/Security, Account Management |
| Identifiers - Device ID | Yes | Yes | Yes when ATT/AppRefer attribution is enabled and authorized | App Functionality, Analytics, Developer Advertising or Marketing |
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
- Superwall collects purchase history/subscription state and app user
  identifiers for entitlement management.
- Gleap may collect support contact details and diagnostic/support conversation
  details when a user contacts support.
- AppRefer/ATT attribution means device/advertising identifiers may be used for
  campaign attribution. Treat Device ID as tracking when ATT authorization and
  attribution are enabled.

## Published ASC Data Usage Rows

Readback after publish returned these 16 rows:

- `NAME` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `EMAIL_ADDRESS` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `HEALTH` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `HEALTH` / `PRODUCT_PERSONALIZATION` / `DATA_LINKED_TO_YOU`
- `OTHER_USER_CONTENT` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `CUSTOMER_SUPPORT` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `PURCHASE_HISTORY` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `USER_ID` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `USER_ID` / `ANALYTICS` / `DATA_LINKED_TO_YOU`
- `DEVICE_ID` / `APP_FUNCTIONALITY` / `DATA_LINKED_TO_YOU`
- `DEVICE_ID` / `ANALYTICS` / `DATA_LINKED_TO_YOU`
- `DEVICE_ID` / no purpose / `DATA_USED_TO_TRACK_YOU`
- `PRODUCT_INTERACTION` / `ANALYTICS` / `DATA_LINKED_TO_YOU`
- `CRASH_DATA` / `ANALYTICS` / `DATA_LINKED_TO_YOU`
- `PERFORMANCE_DATA` / `ANALYTICS` / `DATA_LINKED_TO_YOU`
- `OTHER_DIAGNOSTIC_DATA` / `ANALYTICS` / `DATA_LINKED_TO_YOU`

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
  are tied to Firebase/Superwall/Gleap identifiers.
- Do not claim `Data Not Collected`; BabyRelay is a shared-care app and
  necessarily collects family care data.
- If AppRefer attribution is disabled for the submitted build, revisit the
  `Device ID` tracking row before final submission.
