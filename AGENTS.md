# BabyRelay

## Overview

BabyRelay is a shared baby care handoff app for parents and caregivers. The first product wedge is one-tap sleep logging, realtime caregiver sync, next-up guidance, and clear handoff summaries, but the product should be framed as shared baby care rather than a sleep-only tracker.

Core promise:

> One baby, every caregiver, zero handoff guesswork.

## Product Shape

- Shared baby care state for parents, partners, grandparents, nannies, and daycare helpers.
- One-tap logging for high-frequency care moments.
- Realtime shared timeline with logged-by attribution.
- "Next Up" guidance based on recent care activity and simple deterministic rules.
- Handoff summaries that explain what happened and what the next caregiver should know.
- Family/care-team subscription, not a single-player tracker.

## Tech Stack

- **Framework**: Flutter
- **Platforms**: iOS first, Android after core MVP unless otherwise directed
- **Backend**: Dedicated Firebase project
- **Auth**: Firebase Auth
- **Data**: Cloud Firestore
- **Analytics**: Firebase Analytics with privacy-safe event payloads
- **Crash reporting**: Firebase Crashlytics
- **Messaging**: Firebase Cloud Messaging
- **Subscriptions**: RevenueCat
- **Attribution**: AppRefer
- **Support**: Gleap
- **Store tooling**: AppStore Copilot

## iOS Defaults

New consumer iOS apps are iPhone-only and portrait-only unless Joe explicitly asks otherwise.

- Set `TARGETED_DEVICE_FAMILY = 1`.
- Set `UIRequiresFullScreen = true`.
- Keep supported orientations to portrait only.

## Architecture Defaults

Prefer:

- `flutter_bloc` for state management
- `go_router` for navigation
- `freezed` / `json_serializable` for immutable models when complexity justifies it
- Pure Dart services for deterministic care guidance logic
- Firebase and provider wrappers behind app-owned services

Suggested feature folders:

```text
lib/
  core/
    analytics/
    auth/
    design/
    notifications/
    purchases/
    routing/
  features/
    onboarding/
    today/
    logging/
    handoff/
    care_team/
    paywall/
    settings/
```

## Privacy And Safety

This app handles child and family care data.

- Do not send baby names, caregiver names, free-text notes, or sensitive health details to analytics.
- Keep guidance framed as scheduling and handoff support, not medical advice.
- Do not promise sleep-training outcomes.
- Provide clear data deletion and caregiver access removal paths.
- Use deterministic, explainable rules before any AI/ML claims.

## Current Plan

Read `docs/plans/core/overview.md` before scaffolding or implementing. That document contains the current MVP direction, Firestore model, services, monetization, acquisition hooks, risks, and 4-week build plan.

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

## Current Implementation Notes

The MVP is implemented and runs fully on-device (no credentials):

- `lib/data/local_store.dart` is the persistence seam (SharedPreferences now,
  Firestore later). `FamilyRepository` is the single source of truth for the
  shared family state and exposes the mutation API Firestore will mirror.
- `lib/domain/engine/sleep_prediction_engine.dart` implements the wake-window
  table, short-nap adjustment, bedtime compression, drift clamp, and 4-of-7
  transition detection from `docs/plans/core/overview.md`. Pure Dart, tested.
- `lib/domain/services/handoff_service.dart` generates the plain-language
  handoff summary. Pure Dart, tested.
- `PurchaseService` mocks RevenueCat (`pro` entitlement, special annual launch
  offer plus monthly/annual trial plans). `AnalyticsService` enforces the
  allowlist + no-PII rule.
- Free tier allows owner + 1 caregiver; inviting beyond that gates on the
  paywall.
- Settings has a "Load sample day" action that seeds a believable demo day.

