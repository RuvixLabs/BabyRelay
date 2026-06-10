# BabyRelay Core Plan

Date: 2026-06-10

Source context:
- Napper competitor research in Mission Control reference bank
- Claude Code read-only planning brief
- Mission Control new-project and app-scaffold defaults

## Direction

BabyRelay is a shared baby care handoff app.

The first killer workflow is sleep and nap timing because Napper has proven that parents pay for decision relief around wake windows. BabyRelay should not be positioned as a sleep-only tracker. The wider product is a shared care state for everyone looking after the baby.

Positioning:

> One baby, every caregiver, zero handoff guesswork.

Product pattern:

```text
tiny care log -> shared timeline -> next-up guidance -> clean caregiver handoff
```

Initial wedge:

```text
one-tap sleep log -> next nap/bedtime window -> shared caregiver handoff
```

## Why This Is Not A Napper Clone

Napper's strength is single-player sleep decision relief: log sleep and get a next nap/bedtime suggestion.

BabyRelay's wedge is multiplayer care:
- Parents, partners, grandparents, nannies, and daycare helpers share one care timeline.
- Each event shows who logged it.
- The next caregiver can understand the baby's day without texting back and forth.
- The subscription story is family/care-team value, not just one person's tracker.

This also creates a natural invite loop. A useful account wants at least one other caregiver.

## MVP Screens

### Today

The home screen is the demo.

Elements:
- Top `Next Up` card.
- One-tap `Asleep` / `Awake` state button.
- Day timeline.
- Logged-by avatar dots.
- Short explanation for predicted nap/bedtime windows.
- Entry point to the handoff sheet.

Critical rule:
- From cold app open, logging asleep or awake must be one tap.

### Handoff

Auto-generated summary for the next caregiver.

Example:

```text
Woke at 2:45pm from a 40-minute nap.
Next nap window opens around 4:20pm.
Two naps so far today.
Last note from Sara: bottle finished before nap.
```

Support sharing as plain text so non-app caregivers can still receive a useful handoff.

### Timeline Edit

Editing must be fast and forgiving.

Requirements:
- Adjust event start/end.
- Delete events.
- Merge duplicate/overlapping sleep entries.
- Add optional short notes.
- Keep light edited-by attribution.

### Care Team

Requirements:
- Invite by link, QR, and short code.
- Roles: owner and caregiver.
- Logged-by attribution.
- Remove/revoke access.
- Optional "on duty" indicator later.

### Onboarding

Keep short:
- Baby nickname/name.
- Date of birth.
- Typical wake time.
- Typical bedtime.
- Rough current naps per day.
- Primary caregiver.
- Invite partner/caregiver prompt.

Onboarding should seed the deterministic guidance model.

### Paywall

RevenueCat-backed, trial-first.

The paid story is:
- unlimited caregivers
- shared handoff sheets
- cross-caregiver notifications
- history
- transition guidance
- exports/shares

## Deterministic V1 Guidance

Do not build ML in v1.

Use a pure Dart rules engine. Sleep/nap timing is the first ruleset.

Example:

```text
ageWeeks -> napsPerDay + wakeWindowTable

0-12 weeks: 4-5 naps, 45-75 min wake windows
3-6 months: 3-4 naps, 1h45-2h30 wake windows
6-9 months: 3 naps, 2h15-3h wake windows
9-14 months: 2 naps, 2h45-3h45 wake windows
14-24 months: 1-2 naps, 4h-6h wake windows

nextNapStart =
  lastWakeTime
  + wakeWindowForAgeAndNapIndex
  + personalDrift
  - shortNapAdjustment
  + bedtimeCompression
```

Adjustments:
- Short nap: if last nap is under 45 minutes, shrink next wake window by 15-20%.
- Bedtime anchor: compress/stretch final wake window around target bedtime.
- Personal drift: EWMA of observed vs predicted timing over the last 7 days, clamped to plus/minus 20 minutes.

Transition handling:
- If observed naps per day disagrees with the age table on 4 of the last 7 days, show a transition banner.
- Let the parent pick which schedule fits better.

Night waking:
- Log it.
- Show it.
- Do not coach or promise to solve night waking in v1.

Future care modules can add deterministic guidance for feeds, medication reminders, supplies, and daycare notes, but v1 should keep sleep as the sharpest proof point.

## Firestore Model

Family is the subscription and access unit.

```text
families/{familyId}
  createdBy: uid
  inviteCode: string
  subscriptionOwnerUid: uid
  createdAt: timestamp

families/{familyId}/members/{uid}
  role: owner|caregiver
  displayName: string
  avatarColor: string
  joinedAt: timestamp
  removedAt?: timestamp

families/{familyId}/babies/{babyId}
  name: string
  dob: timestamp
  settings:
    targetWakeTime: string
    targetBedtime: string
    scheduleOverride?: string
  createdAt: timestamp

families/{familyId}/babies/{babyId}/events/{eventId}
  type: sleep|wake|feed|diaper|medicine|note|nightWaking
  startAt: timestamp
  endAt?: timestamp
  loggedBy: uid
  editedBy: uid[]
  source: tap|edit|merge
  note?: string
  createdAt: timestamp
  updatedAt: timestamp

families/{familyId}/babies/{babyId}/dailySummaries/{yyyy-mm-dd}
  napsCount: number
  totalDaySleepMinutes: number
  lastWakeAt: timestamp
  nextNapWindowStart?: timestamp
  nextNapWindowEnd?: timestamp
  generatedHandoffText?: string

users/{uid}
  currentFamilyId: string
  fcmTokens: string[]
  rcAppUserId: string
  createdAt: timestamp
```

Security:
- Users only access families where they are active members.
- Caregivers can create/edit care events.
- Owners can remove members and delete family data.
- Free-text notes must not go to analytics.

Offline:
- Enable Firestore offline persistence.
- Merge or flag overlapping sleep events clearly.

## Flutter Services

- `AuthService`: anonymous auth, sign-in upgrade, account deletion.
- `FamilyService`: create family, invite code/link, join, leave, roles.
- `CareLogService`: one-tap logging, event CRUD, overlap merge.
- `SleepPredictionEngine`: pure Dart next-window calculation.
- `HandoffService`: deterministic handoff text generation.
- `NotificationService`: local reminders and caregiver update notifications.
- `AnalyticsService`: privacy-safe event wrapper.
- `PurchaseService`: RevenueCat entitlement and restore.

## Analytics

Core events:

```text
onboarding_started
onboarding_step_viewed
onboarding_completed
baby_profile_created
care_event_logged
care_event_edited
next_up_viewed
handoff_opened
handoff_shared
caregiver_invite_started
caregiver_invite_sent
caregiver_joined
notification_enabled
notification_tapped
paywall_viewed
plan_selected
purchase_started
purchase_completed
purchase_failed
restore_tapped
restore_completed
```

Do not log:
- baby names
- caregiver names
- free-text notes
- sensitive health details
- exact medication names

## Monetization

Free:
- one baby
- one caregiver
- one-tap care timeline
- today's next-up guidance

Premium: `BabyRelay Family`
- $9.99/month
- $59.99/year
- 7-day trial
- unlimited caregivers
- handoff sheets
- cross-caregiver notifications
- full history
- transition guidance
- export/share summaries

Paywall placements:
- Soft paywall after onboarding.
- Hard gate on inviting a second caregiver.
- Trial-first copy.

RevenueCat:
- entitlement: `pro`
- products: monthly and annual
- do not hardcode store product IDs in business logic

## 4-Week Build Plan

### Week 1 - Foundation

- Scaffold Flutter app.
- Configure iOS as iPhone-only, portrait-only.
- Create dedicated Firebase project.
- Wire Firebase Auth, Firestore, Analytics, Crashlytics, Messaging.
- Add RevenueCat, AppRefer, Gleap packages.
- Build data models and security rules.
- Build pure Dart sleep prediction engine.
- Unit-test wake-window and transition logic.

### Week 2 - Core Loop

- Build Today screen.
- Build one-tap `Asleep/Awake` logging.
- Build shared timeline with logged-by attribution.
- Build event edit/detail flow.
- Enable Firestore offline persistence.
- Add next-up countdown card.
- Add local nap-window reminders.

### Week 3 - Shared Care Wedge

- Build care team invite/join flow.
- Add QR, link, and short invite code.
- Add realtime multi-device sync.
- Build handoff sheet and share flow.
- Add caregiver update notifications.
- Add transition-detection banner.
- Add merge/flag handling for overlapping sleep entries.

### Week 4 - Monetize And Package Test Build

- Build onboarding.
- Build RevenueCat paywall.
- Add AppRefer attribution links before paid traffic.
- Add Gleap support entry.
- Finalize analytics events.
- QA simulator/device.
- Prepare AppStore Copilot metadata project.
- Package TestFlight build.
- Start beta with 10-20 families.

## Acquisition Hooks

Meta/UGC hooks:
- `No more asking "when did the baby last sleep?"`
- `The baby handoff app for exhausted parents.`
- `One screen for mom, dad, grandma, and the nanny.`
- `Stop doing nap math in your Notes app.`
- `The fastest way to tell the next caregiver what happened today.`

UGC formats:
- two phones updating the same baby timeline
- messy notes app versus clean BabyRelay handoff
- 2am partner handoff
- grandparent asking the same question repeatedly
- daycare pickup confusion

ASO keywords:
- baby tracker
- shared baby tracker
- baby sleep tracker
- baby tracker for couples
- nanny baby log
- baby handoff app
- newborn sleep tracker
- nap tracker
- baby schedule

AppRefer:
- Every invite link should be attributable.
- Handoff shares to non-users should include a tracked app link.

## Risks

- Cold-start trust: label early predictions as starter guidance.
- Competition: Napper/Huckleberry can add sharing; BabyRelay must be designed around handoff from screen one.
- Privacy: child/family data requires clean analytics and deletion paths.
- Edit friction: correcting logs must be easy.
- Notification fatigue: send only important care-state changes.
- Liability: avoid medical or sleep-training promises.
- Multi-writer conflicts: overlapping logs need clear merge handling.

## What Not To Build In V1

- No ML prediction model.
- No AI parenting coach branding.
- No sleep-training course.
- No white-noise player.
- No audio monitoring.
- No full pediatric/provider portal.
- No daycare B2B portal.
- No complex charts before the core loop works.
- No public community.
- No iPad/landscape-first work.
- No web dashboard.

## Critical Demo

The product must prove this in under 20 seconds:

1. One caregiver taps `Asleep`.
2. Another caregiver sees the updated timeline immediately.
3. The next-up card changes.
4. The handoff sheet explains the day in plain language.

That is the ad, the product, and the retention mechanic.

