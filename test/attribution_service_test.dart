import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:babyrelay/core/attribution/attribution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ATT finishes before AppRefer and RevenueCat identity bridge', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.notDetermined,
    );
    final service = AttributionService(
      apiKey: 'pk_test_example123',
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
      'revenuecat_status',
      'revenuecat_user_id',
      'apprefer_user_id:rc_user',
      'apprefer_device_id',
      'revenuecat_attributes',
    ]);
    expect(platform.attributes, {'appreferId': 'ar_device'});
  });

  test('denied ATT still initializes AppRefer', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.denied,
      revenueCatConfigured: false,
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
      'revenuecat_status',
    ]);
  });

  test('ATT failure does not block AppRefer initialization', () async {
    final platform = _FakeAttributionPlatform(
      trackingStatus: TrackingStatus.notDetermined,
      failTrackingStatus: true,
      revenueCatConfigured: false,
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
      'revenuecat_status',
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
        revenueCatConfigured: false,
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
    this.revenueCatConfigured = true,
  });

  final TrackingStatus trackingStatus;
  final bool failTrackingStatus;
  final bool revenueCatConfigured;
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
  Future<String> getRevenueCatAppUserId() async {
    events.add('revenuecat_user_id');
    return 'rc_user';
  }

  @override
  Future<TrackingStatus> getTrackingAuthorizationStatus() async {
    events.add('att_status');
    if (failTrackingStatus) throw StateError('ATT unavailable');
    return trackingStatus;
  }

  @override
  Future<bool> isRevenueCatConfigured() async {
    events.add('revenuecat_status');
    return revenueCatConfigured;
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
  Future<void> setRevenueCatAttributes(Map<String, String> attributes) async {
    events.add('revenuecat_attributes');
    this.attributes = attributes;
  }
}
