import 'package:babyrelay/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release builds require Firebase shared sync', () {
    expect(
      () => validateFirebaseReleaseConfiguration(
        releaseMode: true,
        firebaseConfigured: false,
      ),
      throwsStateError,
    );
    expect(
      () => validateFirebaseReleaseConfiguration(
        releaseMode: true,
        firebaseConfigured: true,
      ),
      returnsNormally,
    );
    expect(
      () => validateFirebaseReleaseConfiguration(
        releaseMode: false,
        firebaseConfigured: false,
      ),
      returnsNormally,
    );
  });

  test('debug builds may omit the AppRefer SDK key', () {
    expect(
      () => validateAppReferReleaseKey(releaseMode: false, apiKey: ''),
      returnsNormally,
    );
  });

  test('release builds require a non-placeholder live AppRefer key', () {
    for (final key in ['', 'pk_test_example123', 'pk_live_...', 'replace_me']) {
      expect(
        () => validateAppReferReleaseKey(releaseMode: true, apiKey: key),
        throwsStateError,
        reason: 'key should be rejected without exposing it',
      );
    }

    expect(
      () => validateAppReferReleaseKey(
        releaseMode: true,
        apiKey: 'pk_live_example123',
      ),
      returnsNormally,
    );
  });

  test('mobile release builds require a platform-specific Superwall key', () {
    for (final key in ['', 'replace_me', 'pk_short']) {
      expect(
        () => validateSuperwallReleaseKey(
          releaseMode: true,
          platform: TargetPlatform.iOS,
          apiKey: key,
        ),
        throwsStateError,
      );
    }

    expect(
      () => validateSuperwallReleaseKey(
        releaseMode: true,
        platform: TargetPlatform.android,
        apiKey: 'pk_babyrelay_public_sdk_key_12345',
      ),
      returnsNormally,
    );
    expect(
      () => validateSuperwallReleaseKey(
        releaseMode: true,
        platform: TargetPlatform.macOS,
        apiKey: '',
      ),
      returnsNormally,
    );
  });
}
