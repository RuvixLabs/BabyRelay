# BabyRelay

Shared baby care handoff app for parents and caregivers.

> One baby, every caregiver, zero handoff guesswork.

BabyRelay is a Flutter app: one-tap care logging, a shared timeline with
logged-by attribution, deterministic next-nap/bedtime guidance, and a
plain-language handoff summary for the next caregiver.

## Status

Local MVP/prototype. Runs fully on-device with local persistence — no
credentials needed. Firebase, RevenueCat, AppRefer, Gleap, and AppStore
Copilot plug in behind existing service seams (see `lib/main.dart` and
Settings → Integrations in the app).

## Commands

```bash
# Development
flutter pub get
flutter run            # iOS simulator or device

# Checks
flutter analyze
flutter test
dart format lib test
```

## Architecture

```text
lib/
  main.dart                 # composition root (local stores; Firebase later)
  app/                      # MaterialApp.router, go_router routes, nav shell
  core/
    analytics/              # privacy-safe allowlisted analytics wrapper
    design/                 # RelayTheme (warm light + night dark), shared widgets
    purchases/              # PurchaseService — mock of RevenueCat entitlement `pro`
    util/                   # formatting helpers
  data/
    local_store.dart        # key-value seam (SharedPreferences / in-memory)
    family_repository.dart  # shared family state: baby, caregivers, events
  domain/
    models/                 # CareEvent, Caregiver, BabyProfile (pure Dart)
    engine/                 # SleepPredictionEngine — deterministic wake windows
    services/               # HandoffService, DayContextBuilder
  features/
    onboarding/  today/  timeline/  handoff/  care_team/  paywall/  settings/
```

State: `flutter_bloc` Cubit for the Today screen; `ChangeNotifier`
repositories provided via `provider`. Navigation: `go_router` with a
stateful bottom-nav shell (Today / Care team / Settings).

The prediction engine and handoff generator are pure Dart with unit tests —
no Flutter imports — so guidance stays deterministic and explainable.

## iOS defaults

iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), portrait-only,
`UIRequiresFullScreen = true`.

## Docs

- `AGENTS.md` — agent/project instructions
- `docs/plans/core/overview.md` — MVP direction, rules engine spec, Firestore model
