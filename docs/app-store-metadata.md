# BabyRelay App Store Metadata

Canonical first-pass App Store metadata draft for AppStore Co-Pilot and
App Store Connect review. Current scope is `en-US`.

## App Info

| Field | Draft | Limit | Count |
|---|---|---:|---:|
| Name | BabyRelay: Shared Baby Care | 30 | 27 |
| Subtitle | Baby Log & Care Sync | 30 | 20 |
| Privacy Policy URL | https://appstorecopilot.com/legal/3omln7px/privacy | URL | - |
| Terms of Service URL | https://appstorecopilot.com/legal/3omln7px/terms | URL | - |

## Version Metadata

| Field | Draft | Limit | Count |
|---|---|---:|---:|
| Keywords | newborn,infant,nanny,caregiver,feeding,diaper,nap,tracker,family,pumping,grandparent | 100 | 84 |
| Promotional Text | Keep caregivers synced with one-tap sleep logs and shared timelines. Family care summaries are available with an optional subscription. | 170 | 135 |
| What's New | BabyRelay is launching with one-tap sleep logging, shared baby timelines, care-team invites, and BabyRelay Family subscription features for multi-child support, care summaries, exports, and longer history. | 4000 | 205 |
| Support URL | TBD before submission | URL | - |

## Description

BabyRelay keeps everyone caring for your baby on the same page.

Log sleep, wakes, feeds, diapers, notes, and night wakes in a few taps. Each
entry is tied to a child and caregiver, so parents, partners, grandparents,
nannies, and other helpers can see what happened without digging through
texts.

Built around handoffs, not just tracking:

- One-tap asleep and awake logging
- A shared timeline for each child
- Included next-up sleep guidance based on age, recent naps, and bedtime
- Quick feed, diaper, note, and night-wake logs
- Care-team invites for your included helper
- Optional BabyRelay Family subscription features for extra children, larger
  care teams, care summaries, longer history, and exports
- Delete controls for family data

BabyRelay is for tired families who need a calmer answer to: "when did they
last sleep, eat, or get changed?"

BabyRelay Family is available as an optional subscription purchase. It unlocks
extra children, larger care teams, care summaries, longer history, exports, and
family subscription access.

BabyRelay provides organization and schedule guidance only. It is not medical
advice and does not replace your pediatrician, healthcare provider, or
safe-sleep guidance.

Description count: 1216 / 4000.

## Notes

- Staged in AppStore Co-Pilot before live App Store Connect publish.
- Privacy Policy and Terms of Service are published through AppStore Co-Pilot
  and are linked from the app paywall and Settings.
- Source screenshots captured from the iPhone simulator live at
  `artifacts/app_store_screenshots/raw/2026-06-16/`; the 6.9-inch
  App Store-ready set is staged at
  `artifacts/app_store_screenshots/final/2026-06-16/iphone_69/`.
- Nano Banana generation was attempted through AppStore Co-Pilot/Kie, but the
  job failed with insufficient Kie credits. The deterministic local 6.9-inch
  set is staged in AppStore Co-Pilot as local screenshot changes, not pushed
  live to App Store Connect.
- A stronger pure `gpt-image-2` story-led candidate set, without a paywall
  screenshot, is saved at
  `artifacts/app_store_screenshots/gpt-image-2-story-v2/2026-06-16/iphone_69/`.
  It is uploaded to a separate AppStore Co-Pilot storage path for review, but
  is not promoted over the current staged set and is not pushed live to App
  Store Connect.
- The approved follow-up `gpt-image-2` v3 pop-out set is now promoted/staged in
  AppStore Co-Pilot for `APP_IPHONE_69` / `en-US` with local screenshot
  changes:
  `artifacts/app_store_screenshots/gpt-image-2-story-v3-popouts/2026-06-16/iphone_69/`.
  It replaces the earlier staged screenshot set inside AppStore Co-Pilot but
  has not been pushed live to App Store Connect.
- The copy intentionally avoids medical, safe-sleep, or sleep-training outcome
  promises.
