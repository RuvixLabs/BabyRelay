# Google Play Setup - 2026-06-23

BabyRelay Google Play draft setup artifacts.

Source of truth:

- Play Console developer: Ruvix Ltd, developer ID `7730130263000890927`
- Play app ID: `4973846096696226350`
- Package: `com.ruvixlabs.babyrelay`
- App name: `BabyRelay: Shared Baby Care`

Live work completed:

- Created the Play Console app shell.
- Uploaded the approved glow-face Play icon.
- Uploaded six approved shared-care phone screenshots.
- Uploaded title, short description, full description, and support email.
- Completed Play App content forms: Privacy Policy, Ads, App access,
  Government apps, Financial features, Health apps, Content rating, Target
  audience, and Data safety.
- Created active Google Play subscriptions/base plans:
  - `babyrelay_pro_monthly` / `monthly` / `P1M` / `$9.99` / no active trial
  - `babyrelay_pro_annual` / `annual` / `P1Y` / `$59.99` / 7-day trial
  - `babyrelay_pro_special_annual` / `special-annual` / `P1Y` / `$29.99`

Key reports:

- `play_listing_map.json`
- `listing_metadata/listing_metadata_report.json`
- `app_details/app_details_report.json`
- `icon/upload_report.json`
- `phone_screenshots/upload_report.json`
- `subscriptions/android_subscriptions_report.json`
- `app_content/app_content_summary_after_data_safety.txt`
- `app_content/data_safety_preview_text_final.txt`

Remaining Android launch work:

- Create BabyRelay Android upload signing and upload an AAB to an internal
  track.
- Create/configure the BabyRelay RevenueCat Android app, store its Android
  public SDK key in `mc-vault`, import Play products, and wire RTDN/Pub/Sub.
- Run Android install and RevenueCat purchase/restore smoke before production
  release submission.
