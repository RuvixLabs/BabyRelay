import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:apprefer/apprefer.dart';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

import '../../data/local_store.dart';

abstract interface class AttributionPlatform {
  Future<TrackingStatus> getTrackingAuthorizationStatus();

  Future<TrackingStatus> requestTrackingAuthorization();

  Future<Map<String, Object?>> configureAppRefer(String apiKey);

  Future<bool> waitForSuperwallConfiguration();

  Future<void> setAppReferUserId(String userId);

  Future<String?> getAppReferDeviceId();

  Future<void> setSuperwallAttributes(Map<String, Object> attributes);
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
  Future<Map<String, Object?>> configureAppRefer(String apiKey) async {
    final attribution = await AppReferSDK.configure(
      AppReferConfig(
        apiKey: apiKey,
        debug: kDebugMode,
        logLevel: kDebugMode ? 3 : 1,
      ),
    );
    return attribution?.queryParams.map(
          (key, value) => MapEntry(key, value as Object?),
        ) ??
        const {};
  }

  @override
  Future<bool> waitForSuperwallConfiguration() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    do {
      if (await Superwall.shared.getIsConfigured()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } while (DateTime.now().isBefore(deadline));
    return false;
  }

  @override
  Future<void> setAppReferUserId(String userId) =>
      AppReferSDK.setUserId(userId);

  @override
  Future<String?> getAppReferDeviceId() => AppReferSDK.getDeviceId();

  @override
  Future<void> setSuperwallAttributes(Map<String, Object> attributes) =>
      Superwall.shared.setUserAttributes(attributes);
}

class AttributionService {
  AttributionService({
    required this.apiKey,
    this.userId = '',
    AttributionPlatform? platform,
    LocalStore? store,
    bool? shouldRequestTrackingAuthorization,
    Future<void> Function(Duration)? delay,
  }) : _platform = platform ?? const ProductionAttributionPlatform(),
       _store = store,
       _shouldRequestTrackingAuthorization =
           shouldRequestTrackingAuthorization ??
           defaultTargetPlatform == TargetPlatform.iOS,
       _delay = delay ?? Future<void>.delayed;

  final String apiKey;
  final String userId;
  final AttributionPlatform _platform;
  final LocalStore? _store;
  final bool _shouldRequestTrackingAuthorization;
  final Future<void> Function(Duration) _delay;

  static const _pendingInviteCodeKey =
      'babyrelay.attribution.pending_invite_code.v1';
  static const _handledInviteKey = 'babyrelay.attribution.handled_invite.v1';
  static final _inviteCodePattern = RegExp(
    r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
  );

  Future<String?>? _initialization;

  bool get configured => apiKey.isNotEmpty;

  /// Initializes AppRefer and returns an invite captured before first install.
  ///
  /// A returned code remains pending across relaunches until the join screen is
  /// completed or explicitly dismissed via [consumePendingInviteCode].
  Future<String?> initializeAfterFirstFrame() =>
      _initialization ??= _initializeAfterFirstFrame();

  Future<String?> _initializeAfterFirstFrame() async {
    final persistedInviteCode = await _readStoredCode(_pendingInviteCodeKey);
    if (!configured) return persistedInviteCode;

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

    Map<String, Object?> queryParams;
    try {
      // Configure after the first-visible-launch ATT path has finished, even
      // when the user denies tracking or the ATT API is unavailable.
      queryParams = await _platform.configureAppRefer(apiKey);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] AppRefer initialization failed: $error');
      }
      return persistedInviteCode;
    }

    final deferredInviteCode = await _rememberDeferredInvite(
      queryParams,
      fallback: persistedInviteCode,
    );

    if (deferredInviteCode != null) {
      // Do not make a caregiver wait up to eight seconds for Superwall before
      // opening the invite they installed the app to accept.
      unawaited(_completeIdentityBridge());
    } else {
      await _completeIdentityBridge();
    }
    return deferredInviteCode;
  }

  /// Prevents a cached AppRefer install attribution from reopening the same
  /// invite on every subsequent app launch.
  Future<void> consumePendingInviteCode() async {
    final store = _store;
    if (store == null) return;
    try {
      final pending = _normalizeInviteCode(
        await store.read(_pendingInviteCodeKey),
      );
      if (pending == null) return;
      // AppRefer uses first-touch attribution and returns the same cached
      // result on later launches. A boolean is sufficient and avoids retaining
      // the family invite code after it has been used or dismissed.
      await store.write(_handledInviteKey, 'true');
      await store.delete(_pendingInviteCodeKey);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] could not consume deferred invite: $error');
      }
    }
  }

  Future<String?> _rememberDeferredInvite(
    Map<String, Object?> queryParams, {
    required String? fallback,
  }) async {
    final attributedCode = _normalizeInviteCode(
      queryParams['invite_code'] ?? queryParams['inviteCode'],
    );
    if (attributedCode == null) return fallback;

    if (await _wasDeferredInviteHandled()) {
      await _deleteStoredCode(_pendingInviteCodeKey);
      return null;
    }

    final store = _store;
    if (store != null) {
      try {
        await store.write(_pendingInviteCodeKey, attributedCode);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[attribution] could not persist deferred invite: $error');
        }
      }
    }
    return attributedCode;
  }

  Future<bool> _wasDeferredInviteHandled() async {
    final store = _store;
    if (store == null) return false;
    try {
      return await store.read(_handledInviteKey) == 'true';
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[attribution] could not read deferred invite state: $error',
        );
      }
      return false;
    }
  }

  Future<String?> _readStoredCode(String key) async {
    final store = _store;
    if (store == null) return null;
    try {
      return _normalizeInviteCode(await store.read(key));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] could not read deferred invite: $error');
      }
      return null;
    }
  }

  Future<void> _deleteStoredCode(String key) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.delete(key);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] could not clear deferred invite: $error');
      }
    }
  }

  static String? _normalizeInviteCode(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toUpperCase();
    return _inviteCodePattern.hasMatch(normalized) ? normalized : null;
  }

  Future<void> _completeIdentityBridge() async {
    try {
      if (userId.isNotEmpty) await _platform.setAppReferUserId(userId);
      await _bridgeSuperwallAttribution();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[attribution] identity bridge failed: $error');
      }
    }
  }

  Future<void> _bridgeSuperwallAttribution() async {
    if (!await _platform.waitForSuperwallConfiguration()) return;
    final appReferId = await _platform.getAppReferDeviceId();
    if (appReferId == null || appReferId.isEmpty) return;
    await _platform.setSuperwallAttributes({'appreferId': appReferId});
  }
}
