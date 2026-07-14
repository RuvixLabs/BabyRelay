# BabyRelay — Claude Worker Notes

See `AGENTS.md` for the full project instructions and
`docs/plans/core/overview.md` for the product plan. This file captures
implementation knowledge for the next worker.

## What exists (MVP, local-first)

Full Flutter MVP: onboarding → Today (one-tap sleep, quick logs, timeline,
next-up guidance, child switcher) → handoff sheet → care team invites →
paywall → settings. **Multi-child**: a family has any number of children;
every care event is scoped to a `childId` and the UI focuses one selected
child at a time. Local fallback persists to SharedPreferences as JSON;
production builds can attach Firebase Auth/Firestore sync through
`FirestoreFamilySyncAdapter`.

## Key files

| Concern | Path |
|---|---|
| Composition root | `lib/main.dart` |
| Routes / nav shell | `lib/app/router.dart`, `lib/app/shell.dart` |
| Design system | `lib/core/design/relay_theme.dart` (RelayColors ThemeExtension), `relay_widgets.dart` |
| Shared state | `lib/data/family_repository.dart` (ChangeNotifier, persisted) |
| Persistence seam | `lib/data/local_store.dart` + `lib/data/firestore_family_sync.dart` |
| Child switcher / add-child | `lib/features/children/child_switcher.dart`, `child_form_sheet.dart` |
| Prediction engine | `lib/domain/engine/sleep_prediction_engine.dart` (pure Dart) |
| Handoff text | `lib/domain/services/handoff_service.dart` (pure Dart) |
| Nap derivation | `lib/domain/services/day_context_builder.dart` |
| Purchases seam (abstract + `LocalPurchaseService`) | `lib/core/purchases/purchase_service.dart` |
| Build-time config / integration statuses | `lib/core/config/app_config.dart` |
| Invite codes + share payload | `lib/domain/services/invite_service.dart` |
| Analytics allowlist | `lib/core/analytics/analytics_service.dart` |
| Readiness checklist / provider follow-ups | `docs/production-readiness.md` |

## Multi-child model

- `FamilyState.children: List<BabyProfile>` + `selectedChildId`. Each
  `BabyProfile` has an `id` and a stable `colorIndex` into the avatar
  palette. `CareEvent.childId` scopes every event.
- Repository mutations (`startSleep`, `logFeed`, …) default to the selected
  child; all take an optional `childId`. Sleep state is per child — two
  children can sleep simultaneously; `overlappingSleeps` only matches the
  same child.
- `recentNapCounts`, `eventsOn`, the engine, and handoff are all per-child.
- **No pre-launch migration**: the app never launched, so
  `FamilyState.schemaVersion = 1` IS the clean multi-child shape. `fromJson`
  throws on newer schema versions and the repo starts fresh on any corrupt/
  unknown payload. `CareEvent.fromJson` / `BabyProfile.fromJson` require
  `childId` / `id` — don't reintroduce tolerant fallbacks.
- Free tier: 1 child + owner + 1 caregiver. `kFreeChildLimit` in
  `child_switcher.dart`, `kFreeCaregiverLimit` in `care_team_screen.dart`;
  both gate on `/paywall`. `startAddChildFlow` is the single entry point for
  adding a child (used by the switcher sheet and Settings).
- "Load sample day" seeds the selected child's day AND a demo sibling
  ("Theo") so the switcher is demoable; tests rely on that. The Settings row
  for it (and "Reset entitlement") is `kDebugMode`-only — release builds
  never show demo tooling.

## Design language v2 ("warm editorial nursery")

- `RelayColors` carries the full palette including hero gradients:
  `nightHigh/nightLow/onNight/onNightSoft` (sleep surfaces, starfield) and
  `dawnHigh/dawnLow` (awake next-up hero). Avoid flat beige-on-beige — hero
  moments should use these gradients.
- Display font is **Fraunces** (variable TTF in `assets/fonts/`, OFL license
  alongside). Only `displayMedium/displaySmall/headlineMedium` use it, via
  `FontVariation` (wght 590, opsz 50, SOFT 30) — body text stays on the
  system font. Don't use bare `fontWeight` with Fraunces; set the `wght`
  variation instead or it renders thin.
- Custom painters in `relay_widgets.dart`: `StarFieldPainter` (night hero,
  uses saveLayer for the crescent moon cut-out) and `SunArcPainter` (dawn
  hero). `PressableScale` is the standard tap feedback for cards/buttons.
- `ChildAvatar` shows a moon badge when that child is asleep — the switcher
  reads at a glance.
- Timeline is a time-rail (time column · rail with markers · content ·
  caregiver dot), not a list of identical cards.

## Gotchas / decisions

- `context.watch<FamilyRepository>()` works because app.dart uses
  `ChangeNotifierProvider`, NOT `RepositoryProvider` (which never rebuilds on
  `notifyListeners`). Keep it that way.
- The engine uses minutes-since-midnight ints (no `TimeOfDay`) so domain stays
  Flutter-free and testable.
- "Day sleep" = sleep starting 06:00–18:59; everything else is night sleep and
  is excluded from nap counts (`DayContextBuilder.isDaySleep` and
  `FamilyRepository._isDaySleep` must stay in sync).
- The invite QR is a deterministic decorative glyph (`_CodeGlyphPainter`), not
  a scannable QR — swap for a real QR lib with the deep-link integration.
- The care-team local add button stands in for the real join flow (second
  device + invite code) until Firebase/universal links are wired.
- Transition banner "Keep current" pins the age-table nap count as a schedule
  override so the banner stops reappearing; "Switch" pins the observed count.
- iOS is iPhone-only portrait-only (`TARGETED_DEVICE_FAMILY = 1`,
  `UIRequiresFullScreen`, portrait orientations only in Info.plist).
- Analytics: only allowlisted event names; params must be enum-like tokens
  (asserts in debug). Never log names/notes. Child events are
  `child_added/child_switched/child_removed/child_profile_edited` — no child
  ids or names in params.

## Tests

`flutter test` — engine (windows, short nap, bedtime compression, drift
clamp, transitions), handoff text, repository (multi-child add/switch/remove,
event isolation per child, schema versioning + fresh-start on bad payloads,
versioned export envelope, merge/overlap per child, nap counts per child,
persistence round-trip, deletion), purchases (success/cancel/fail/restore/
busy-guard/persistence — `test/purchase_service_test.dart`), invites
(`test/invite_service_test.dart`), and widget smoke tests for the core flows
including child switching, add-child paywall gate, and paywall purchase/
restore outcome handling (`test/app_flow_test.dart`).

## Integration plan (when credentials exist)

Provider keys arrive via `--dart-define` (never committed) and surface in
`lib/core/config/app_config.dart`; full checklist in
`docs/production-readiness.md`.

1. Firebase: `FirestoreFamilySyncAdapter` is implemented behind the same
   repository API. It stores small family metadata at `families/{id}`, children
   at `families/{id}/children`, caregivers at `families/{id}/caregivers`, and
   care logs at `families/{id}/events`. The live listener is bounded to the
   most recent 500 events so app opens and live updates do not scale with
   all-time history.
2. Superwall: `SuperwallPurchaseService` is the release implementation. It
   configures without blocking first paint, presents remotely managed paywalls
   for the four placements, and treats entitlement `pro` as authoritative.
   Keep the local service debug/test-only.
3. AppRefer: keep shared invites as direct
   `https://ourbabyrelay.com/join/<code>` universal links. The website fallback
   forwards first installs through AppRefer link `babyrelay-meta` with an
   `invite_code` query parameter; `AttributionService` restores and consumes
   it. Do not wrap the shared URL in an AppRefer URL or installed-app opening
   will break.
4. Gleap: wire the Settings support row (email fallback already live).
