# Sleep Tracking Research Notes

Date: 2026-06-23

## Sources Checked

- Huckleberry SweetSpot: age-based wake windows adjusted by actual tracked
  sleep patterns, with notifications and manual wake-window controls.
  <https://huckleberrycare.com/blog/sweetspot-your-smart-sleep-timing-companion>
- Huckleberry Manual Mode: paid users can override wake windows during nap
  transitions or when following a specific sleep program.
  <https://huckleberry.zendesk.com/hc/en-us/articles/360053175093-SweetSpot-Manual-Mode-What-is-it-and-how-do-I-use-it>
- Napper: schedule prediction, night waking support, sleep totals, wake times,
  bedtime insights, and parent trust around "no nap math."
  <https://napper.app/en/>
- Nara FAQ: caregivers can log past activity by changing entry start date/time;
  timer entries can be edited when a parent forgot to start or stop.
  <https://nara.com/pages/nara-baby-tracker-faq>
- Nara App Store listing: sleep timer, manual sleep sessions with start/end
  times, graphs/comparisons, wake-window routines, caregiver sharing, and
  multiple children/twins.
  <https://apps.apple.com/us/app/nara-baby-pregnancy-tracker/id1444639029>
- Baby Tracker App Store listing: one-handed tracking, go-back-later details,
  sleep schedule/pattern recognition, and caregiver/doctor sharing.
  <https://apps.apple.com/us/app/baby-tracker-newborn-log/id779656557>
- Baby Connect App Store listing and release notes: synced caregiver tracking,
  reports/trends, timer inconsistency handling, and editable timer starts.
  <https://apps.apple.com/sg/app/baby-connect-baby-tracker/id326574411>
  <https://babyconnect.wordpress.com/author/babyconnect/page/3/>
- ParentLove: one-tap sleep tracking plus reminders that keep caregivers on
  schedule.
  <https://parentlove.me/>
- Parent/community signals on Reddit:
  parents value wake-window accuracy, future nap visibility, user-friendly UI,
  simultaneous caregiver tracking, editable calendar starts, export, and family
  sharing without every caregiver paying separately.
  <https://www.reddit.com/r/sleeptrain/comments/1bkelez/huckleberry_or_napper/>
  <https://www.reddit.com/r/beyondthebump/comments/ienksd/thoughts_on_three_newborn_tracking_apps/>

## Product Lessons

1. Live timers are necessary but not sufficient. Tired caregivers forget to tap
   "start" and "stop," so the app needs a first-class correction path.
2. Retrospective sleep entry should support both naps and overnight sleep with
   start/end date and time, not only "duration."
3. Sleep guidance should explain what changed in plain language. Parents trust
   systems that reduce nap math while still respecting their judgment.
4. Shared-care apps need caregiver attribution and merge/overlap handling
   because two adults may log the same sleep from different devices.
5. Parents want today's answer first: asleep now, awake since last wake, day
   sleep total, nap count, and next window. Historical charts can come later.
6. BabyRelay's differentiator should stay "shared baby care" rather than a pure
   sleep-coaching product. Sleep tracking should feed handoff clarity.

## Implemented From This Pass

- Added a completed-sleep repository mutation for manual retrospective entry.
- Added a Today sleep rhythm card with asleep/awake state, day sleep, night
  sleep, nap count, average nap, longest sleep, and a 24-hour sleep ribbon.
- Added backdated live actions:
  - "Started 10 min ago"
  - "Woke 10 min ago"
  - "Adjust start"
- Added an "Add past sleep" sheet with presets, editable start/end date and
  time, optional note, and validation against future/impossible spans.
- Upgraded existing event editing so sleep entries can change date as well as
  time.
- Added tests for child-scoped retrospective sleep and Today UI sleep tools.

## Later Opportunities

- Schedule settings for manual wake-window overrides, similar to Huckleberry
  Manual Mode, but framed as "family routine" rather than expert medical advice.
- Sleep reminders or notifications for upcoming wind-down windows.
- Weekly trends: average day sleep, night sleep, bedtime, wake time, longest
  sleep, and nap consistency.
- Cross-device conflict resolution UI for an ongoing sleep edited by another
  caregiver.
