# BabyRelay

Shared baby care handoff app for parents and caregivers.

> One baby, every caregiver, zero handoff guesswork.

BabyRelay is a Flutter app: one-tap care logging, a shared timeline with
logged-by attribution, deterministic next-nap/bedtime guidance, and a
plain-language handoff summary for the next caregiver.

## Status

Release-candidate app. Runs fully on-device with local persistence when no
credentials are supplied, and switches on Firebase sync, Superwall paywalls and
subscriptions, Gleap support, and the AppRefer/ATT seam through build-time defines (see
`lib/main.dart`, `lib/core/config/app_config.dart`, and Settings →
Integrations in debug builds).

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
  main.dart                 # composition root (Firebase/Superwall/Gleap seams)
  app/                      # MaterialApp.router, go_router routes, nav shell
  core/
    analytics/              # privacy-safe allowlisted analytics wrapper
    design/                 # RelayTheme (warm light + night dark), shared widgets
    purchases/              # PurchaseService — local + Superwall entitlement `pro`
    support/                # Gleap support wrapper with email fallback
    util/                   # formatting helpers
  data/
    local_store.dart        # key-value seam (SharedPreferences / in-memory)
    family_repository.dart  # local-first family state and sync adapter seam
    firestore_family_sync.dart # Firebase Auth + Firestore implementation
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

iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), portrait-only, iOS 15+,
`UIRequiresFullScreen = true`.

## Docs

- `AGENTS.md` — agent/project instructions
- `docs/production-readiness.md` — provider wiring, build defines, release blockers
- `docs/provider-setup.md` — live Firebase/Superwall/AppRefer/ASC readback
- `docs/plans/core/overview.md` — MVP direction, rules engine spec, Firestore model
