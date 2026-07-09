import 'package:babyrelay/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
