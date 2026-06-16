# BabyRelay Selected App Icon

Selected on 2026-06-16 from the `gpt-image-2-happy-baby-face` pass.

## iOS

The live iOS `AppIcon.appiconset` now uses `07_glow_face` from the happy baby
face concept board. All 19 PNGs in `ios/Runner/Assets.xcassets/AppIcon.appiconset`
were regenerated from the selected 1024 source and verified as opaque with the
expected dimensions.

## Android

This repo currently has no `android/` project directory, so Android assets are
stored as a ready-to-copy pack in `android/`.

The Android pack intentionally uses `android_glow_face_safe_source_1024.png`, a
completed-swaddle version of the selected glow-face concept. The iOS icon is a
closer crop, but that crop looked cut off in Android circle/squircle masks.
The Android-safe source keeps the full baby/swaddle visible in Play Store,
circle, and squircle previews.

## Validation

- iOS app icon dimensions/opacity verified across all catalog PNGs.
- Android pack dimensions/opacity verified for Play Store, adaptive foreground,
  and legacy density PNGs.
- `flutter build ios --simulator --debug --no-pub` passed.
