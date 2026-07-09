import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:apprefer/apprefer.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

abstract interface class AttributionPlatform {
  Future<TrackingStatus> getTrackingAuthorizationStatus();

  Future<TrackingStatus> requestTrackingAuthorization();

  Future<void> configureAppRefer(String apiKey);

  Future<bool> isRevenueCatConfigured();

  Future<String> getRevenueCatAppUserId();

  Future<void> setAppReferUserId(String userId);

  Future<String?> getAppReferDeviceId();

  Future<void> setRevenueCatAttributes(Map<String, String> attributes);
}

class ProductionAttributionPlatform implements AttributionPlatform {
  const ProductionAttributionPlatform();

  @override
  Future<TrackingStatus> getTrackingAuthorizationStatus() =>
      AppTrackingTransparency.trackingAuthorizationStatus;

  @override
  Future<TrackingStatus> requestTrackingAuthorization() =>
      AppTrackingTransparency.requestTrackingAuthorization();

  @override
  Future<void> configureAppRefer(String apiKey) async {
    await AppReferSDK.configure(
      AppReferConfig(
        apiKey: apiKey,
        debug: kDebugMode,
        logLevel: kDebugMode ? 3 : 1,
      ),
    );
  }

  @override
  Future<bool> isRevenueCatConfigured() => rc.Purchases.isConfigured;

  @override
  Future<String> getRevenueCatAppUserId() => rc.Purchases.appUserID;

  @override
  Future<void> setAppReferUserId(String userId) =>
      AppReferSDK.setUserId(userId);

  @override
  Future<String?> getAppReferDeviceId() => AppReferSDK.getDeviceId();

  @override
  Future<void> setRevenueCatAttributes(Map<String, String> attributes) =>
      rc.Purchases.setAttributes(attributes);
}

class AttributionService {
  AttributionService({
    required this.apiKey,
    AttributionPlatform? platform,
    bool? shouldRequestTrackingAuthorization,
    Future<void> Function(Duration)? delay,
  }) : _platform = platform ?? const ProductionAttributionPlatform(),
       _shouldRequestTrackingAuthorization =
           shouldRequestTrackingAuthorization ??
           defaultTargetPlatform == TargetPlatform.iOS,
       _delay = delay ?? Future<void>.delayed;

  final String apiKey;
  final AttributionPlatform _platform;
  final bool _shouldRequestTrackingAuthorization;
  final Future<void> Function(Duration) _delay;

  bool _initializationStarted = false;

  bool get configured => apiKey.isNotEmpty;

  Future<void> initializeAfterFirstFrame() async {
    if (!configured || _initializationStarted) return;
    _initializationStarted = true;

    if (_shouldRequestTrackingAuthorization) {
      try {
        final status = await _platform.getTrackingAuthorizationStatus();
        if (status == TrackingStatus.notDetermined) {
          await _delay(const Duration(milliseconds: 600));
          await _platform.requestTrackingAuthorization();
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[attribution] ATT request failed: $error');
        }
      }
    }

    // Configure after the first-visible-launch ATT path has finished, even
    // when the user denies tracking or the ATT API is unavailable.
    try {
      await _platform.configureAppRefer(apiKey);
      await _bridgeRevenueCatIdentity();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] AppRefer initialization failed: $error');
      }
    }
  }

  Future<void> _bridgeRevenueCatIdentity() async {
    if (!await _platform.isRevenueCatConfigured()) return;

    final appUserId = await _platform.getRevenueCatAppUserId();
    if (appUserId.isNotEmpty) {
      await _platform.setAppReferUserId(appUserId);
    }

    final appReferId = await _platform.getAppReferDeviceId();
    if (appReferId == null || appReferId.isEmpty) return;
    await _platform.setRevenueCatAttributes({'appreferId': appReferId});
  }
}
