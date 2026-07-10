import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:babyrelay/core/attribution/attribution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ATT finishes before AppRefer and Superwall identity bridge', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.notDetermined,
    );
    final service = AttributionService(
      apiKey: 'pk_test_example123',
      userId: 'family_user',
      platform: platform,
      shouldRequestTrackingAuthorization: true,
      delay: (duration) async {
        expect(duration, const Duration(milliseconds: 600));
        platform.events.add('delay');
      },
    );

    await service.initializeAfterFirstFrame();

    expect(platform.events, [
      'att_status',
      'delay',
      'att_request',
      'apprefer_configure',
      'apprefer_user_id:family_user',
      'superwall_status',
      'apprefer_device_id',
      'superwall_attributes',
    ]);
    expect(platform.attributes, {'appreferId': 'ar_device'});
  });

  test('denied ATT still initializes AppRefer', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.denied,
      superwallConfigured: false,
    );
    final service = AttributionService(
      apiKey: 'pk_test_example123',
      platform: platform,
      shouldRequestTrackingAuthorization: true,
    );

    await service.initializeAfterFirstFrame();

    expect(platform.events, [
      'att_status',
      'apprefer_configure',
      'superwall_status',
    ]);
  });

  test('ATT failure does not block AppRefer initialization', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.notDetermined,
      failTrackingStatus: true,
      superwallConfigured: false,
    );
    final service = AttributionService(
      apiKey: 'pk_test_example123',
      platform: platform,
      shouldRequestTrackingAuthorization: true,
    );

    await service.initializeAfterFirstFrame();

    expect(platform.events, [
      'att_status',
      'apprefer_configure',
      'superwall_status',
    ]);
  });

  test(
    'missing key disables initialization and duplicate calls are ignored',
    () async {
      final disabledPlatform = _FakeAttributionPlatform(
        trackingStatus: TrackingStatus.authorized,
      );
      final disabled = AttributionService(
        apiKey: '',
        platform: disabledPlatform,
        shouldRequestTrackingAuthorization: true,
      );
      await disabled.initializeAfterFirstFrame();
      expect(disabledPlatform.events, isEmpty);

      final platform = _FakeAttributionPlatform(
        trackingStatus: TrackingStatus.authorized,
        superwallConfigured: false,
      );
      final service = AttributionService(
        apiKey: 'pk_test_example123',
        platform: platform,
        shouldRequestTrackingAuthorization: true,
      );
      await service.initializeAfterFirstFrame();
      await service.initializeAfterFirstFrame();
      expect(
        platform.events.where((event) => event == 'apprefer_configure'),
        hasLength(1),
      );
    },
  );
}

class _FakeAttributionPlatform implements AttributionPlatform {
  _FakeAttributionPlatform({
    required this.trackingStatus,
    this.failTrackingStatus = false,
    this.superwallConfigured = true,
  });

  final TrackingStatus trackingStatus;
  final bool failTrackingStatus;
  final bool superwallConfigured;
  final List<String> events = [];
  Map<String, String>? attributes;

  @override
  Future<void> configureAppRefer(String apiKey) async {
    expect(apiKey, 'pk_test_example123');
    events.add('apprefer_configure');
  }

  @override
  Future<String?> getAppReferDeviceId() async {
    events.add('apprefer_device_id');
    return 'ar_device';
  }

  @override
  Future<TrackingStatus> getTrackingAuthorizationStatus() async {
    events.add('att_status');
    if (failTrackingStatus) throw StateError('ATT unavailable');
    return trackingStatus;
  }

  @override
  Future<bool> waitForSuperwallConfiguration() async {
    events.add('superwall_status');
    return superwallConfigured;
  }

  @override
  Future<TrackingStatus> requestTrackingAuthorization() async {
    events.add('att_request');
    return TrackingStatus.denied;
  }

  @override
  Future<void> setAppReferUserId(String userId) async {
    events.add('apprefer_user_id:$userId');
  }

  @override
  Future<void> setSuperwallAttributes(Map<String, Object> attributes) async {
    events.add('superwall_attributes');
    this.attributes = attributes.cast<String, String>();
  }
}
