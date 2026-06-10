# BabyRelay — Claude Worker Notes

See `AGENTS.md` for the full project instructions and
`docs/plans/core/overview.md` for the product plan. This file captures
implementation knowledge for the next worker.

## What exists (MVP, local-only)

Full Flutter MVP: onboarding → Today (one-tap sleep, quick logs, timeline,
next-up guidance) → handoff sheet → care team invites → paywall → settings.
No backend; everything persists to SharedPreferences as JSON.

## Key files

| Concern | Path |
|---|---|
| Composition root | `lib/main.dart` |
| Routes / nav shell | `lib/app/router.dart`, `lib/app/shell.dart` |
| Design system | `lib/core/design/relay_theme.dart` (RelayColors ThemeExtension), `relay_widgets.dart` |
| Shared state | `lib/data/family_repository.dart` (ChangeNotifier, persisted) |
| Persistence seam | `lib/data/local_store.dart` (swap for Firestore later) |
| Prediction engine | `lib/domain/engine/sleep_prediction_engine.dart` (pure Dart) |
| Handoff text | `lib/domain/services/handoff_service.dart` (pure Dart) |
| Nap derivation | `lib/domain/services/day_context_builder.dart` |
| Mock RevenueCat | `lib/core/purchases/purchase_service.dart` |
| Analytics allowlist | `lib/core/analytics/analytics_service.dart` |

## Gotchas / decisions

- `context.watch<FamilyRepository>()` works because app.dart uses
  `ChangeNotifierProvider`, NOT `RepositoryProvider` (which never rebuilds on
  `notifyListeners`). Keep it that way.
- The engine uses minutes-since-midnight ints (no `TimeOfDay`) so domain stays
  Flutter-free and testable.
- "Day sleep" = sleep starting 06:00–18:59; everything else is night sleep and
  is excluded from nap counts (`DayContextBuilder.isDaySleep` and
  `FamilyRepository._isDaySleep` must stay in sync).
- Free tier = owner + 1 caregiver. The invite flow gates on `/paywall` beyond
  that (`kFreeCaregiverLimit` in `care_team_screen.dart`).
- The invite QR is a deterministic decorative glyph (`_CodeGlyphPainter`), not
  a scannable QR — swap for a real QR lib with the deep-link integration.
- The care-team "add directly" button is the demo stand-in for the real join
  flow (second device + invite code).
- Transition banner "Keep current" pins the age-table nap count as a schedule
  override so the banner stops reappearing; "Switch" pins the observed count.
- iOS is iPhone-only portrait-only (`TARGETED_DEVICE_FAMILY = 1`,
  `UIRequiresFullScreen`, portrait orientations only in Info.plist).
- Analytics: only allowlisted event names; params must be enum-like tokens
  (asserts in debug). Never log names/notes.

## Tests

`flutter test` — 35 tests: engine (windows, short nap, bedtime compression,
drift clamp, transitions), handoff text, repository (merge/overlap, nap
counts, persistence round-trip, deletion), and widget smoke tests for the
core flows (`test/app_flow_test.dart`).

## Integration plan (when credentials exist)

1. Firebase: implement Firestore-backed `FamilyRepository` behind the same
   API; model in `docs/plans/core/overview.md`.
2. RevenueCat: replace `PurchaseService` internals; entitlement id `pro`.
3. AppRefer: attach attribution to the invite link in `care_team_screen.dart`.
4. Gleap: wire the Settings support row.
