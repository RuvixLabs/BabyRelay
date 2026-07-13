// Central build-time configuration.
//
// Provider credentials are NEVER checked into the repo. Each one arrives as
// a `--dart-define` at build time (or stays empty, in which case the app
// runs fully local and the related feature shows a graceful disabled state):
//
// ```sh
// flutter build ios \
//   --dart-define=SUPERWALL_IOS_API_KEY=pk_... \
//   --dart-define=SUPERWALL_ANDROID_API_KEY=pk_... \
//   --dart-define=GLEAP_SDK_KEY=... \
//   --dart-define=APPREFER_API_KEY=pk_live_... \
//   --dart-define=APPREFER_LINK_ID=...
// ```
//
// Firebase is configured by its platform files (GoogleService-Info.plist /
// google-services.json), so it gets a boolean define instead of a key.
import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const String appVersion = '1.0';

  /// Always-available support channel; the Gleap widget replaces this as the
  /// primary path once [gleapSdkKey] is provided.
  static const String supportEmail = 'support@ruvixlabs.com';
  static const String privacyPolicyUrl =
      'https://appstorecopilot.com/legal/3omln7px/privacy';
  static const String termsOfServiceUrl =
      'https://appstorecopilot.com/legal/3omln7px/terms';

  /// Host for caregiver invite links (`https://<host>/join/<code>`). The
  /// universal-link handler ships with the Firebase backend integration.
  static const String inviteLinkHost = 'babyrelay.app';

  // --- Provider wiring (empty ⇒ not configured, app stays local-only) ----

  static const bool firebaseConfigured = bool.fromEnvironment(
    'FIREBASE_CONFIGURED',
  );
  static const String superwallIosApiKey = String.fromEnvironment(
    'SUPERWALL_IOS_API_KEY',
  );
  static const String superwallAndroidApiKey = String.fromEnvironment(
    'SUPERWALL_ANDROID_API_KEY',
  );

  static String get superwallApiKey {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => superwallIosApiKey,
      TargetPlatform.android => superwallAndroidApiKey,
      _ => '',
    };
  }

  static const String gleapSdkKey = String.fromEnvironment('GLEAP_SDK_KEY');
  static const String appReferApiKey = String.fromEnvironment(
    'APPREFER_API_KEY',
  );
  static const String appReferLinkId = String.fromEnvironment(
    'APPREFER_LINK_ID',
  );

  static void validateReleaseConfiguration() {
    validateSuperwallReleaseKey(
      releaseMode: kReleaseMode,
      platform: defaultTargetPlatform,
      apiKey: superwallApiKey,
    );
    validateAppReferReleaseKey(
      releaseMode: kReleaseMode,
      apiKey: appReferApiKey,
    );
  }
}

void validateSuperwallReleaseKey({
  required bool releaseMode,
  required TargetPlatform platform,
  required String apiKey,
}) {
  if (!releaseMode ||
      (platform != TargetPlatform.iOS && platform != TargetPlatform.android)) {
    return;
  }
  final isPublicSdkKey = RegExp(r'^pk_[A-Za-z0-9_-]{20,}$').hasMatch(apiKey);
  if (!isPublicSdkKey) {
    throw StateError(
      'Release builds require the platform-specific SUPERWALL API key.',
    );
  }
}

void validateAppReferReleaseKey({
  required bool releaseMode,
  required String apiKey,
}) {
  if (!releaseMode) return;
  final isLiveKey = RegExp(r'^pk_live_[A-Za-z0-9_-]{8,}$').hasMatch(apiKey);
  if (!isLiveKey) {
    throw StateError(
      'Release builds require a non-placeholder live APPREFER_API_KEY.',
    );
  }
}

// One production service the app integrates with, and whether this build
// has what it needs to turn that integration on.
class Integration {
  const Integration({
    required this.name,
    required this.detail,
    required this.configured,
  });

  final String name;
  final String detail;
  final bool configured;
}

// Snapshot of every provider seam, for the Settings status list and for
// startup decisions (what to initialize vs. leave in local mode).
abstract final class Integrations {
  static final List<Integration> all = [
    Integration(
      name: 'Firebase',
      detail: 'Auth, Firestore sync, Analytics, Crashlytics, Messaging',
      configured: AppConfig.firebaseConfigured,
    ),
    Integration(
      name: 'Superwall',
      detail: 'Remote paywalls and subscriptions behind the `pro` entitlement',
      configured: AppConfig.superwallApiKey != '',
    ),
    Integration(
      name: 'AppRefer',
      detail: 'Install attribution bridged to the Superwall user',
      configured: AppConfig.appReferApiKey != '',
    ),
    Integration(
      name: 'Gleap',
      detail: 'In-app support chat',
      configured: AppConfig.gleapSdkKey != '',
    ),
  ];
}
