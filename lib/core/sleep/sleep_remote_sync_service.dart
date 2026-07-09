import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/family_repository.dart';
import 'sleep_remote_message_handler.dart';

enum ActivityKitTokenKind { pushToStart, activityUpdate }

class ActivityKitTokenUpdate {
  const ActivityKitTokenUpdate({
    required this.kind,
    required this.token,
    this.eventId,
  });

  final ActivityKitTokenKind kind;
  final String token;
  final String? eventId;
}

abstract class SleepRemoteTokenStore {
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String familyId,
    required String platform,
    required String? fcmToken,
  });

  Future<void> saveActivityKitPushToStartToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String token,
  });

  Future<void> saveActivityKitUpdateToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String eventId,
    required String token,
  });
}

abstract class ActivityKitTokenSource {
  Stream<ActivityKitTokenUpdate> get updates;
  Future<void> dispose();
}

abstract class RemoteMessagingTokenSource {
  Future<String?> getAPNSToken();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<Map<String, dynamic>> get foregroundMessages;
}

class SleepRemoteSyncService {
  SleepRemoteSyncService({
    required FamilyRepository familyRepository,
    required String userId,
    required String deviceId,
    required SleepRemoteTokenStore tokenStore,
    required RemoteMessagingTokenSource messaging,
    required ActivityKitTokenSource activityKitTokens,
    String? platform,
    Stream<String?>? userIdChanges,
    List<Duration>? initialTokenRetryDelays,
    Future<void> Function(Duration)? delay,
  }) : _repo = familyRepository,
       _userId = userId,
       _deviceId = deviceId,
       _tokenStore = tokenStore,
       _messaging = messaging,
       _activityKitTokens = activityKitTokens,
       _platform = platform ?? _platformName(),
       _userIdChanges = userIdChanges ?? const Stream<String?>.empty(),
       _initialTokenRetryDelays =
           initialTokenRetryDelays ??
           const [
             Duration(milliseconds: 500),
             Duration(seconds: 2),
             Duration(seconds: 5),
           ],
       _delay = delay ?? Future<void>.delayed;

  final FamilyRepository _repo;
  String? _userId;
  final String _deviceId;
  final SleepRemoteTokenStore _tokenStore;
  final RemoteMessagingTokenSource _messaging;
  final ActivityKitTokenSource _activityKitTokens;
  final String _platform;
  final Stream<String?> _userIdChanges;
  final List<Duration> _initialTokenRetryDelays;
  final Future<void> Function(Duration) _delay;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _fcmToken;
  bool _started = false;
  bool _disposed = false;
  int _tokenRevision = 0;

  static Future<SleepRemoteSyncService> create({
    required FamilyRepository familyRepository,
    required String deviceId,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) async {
    final resolvedAuth = auth ?? FirebaseAuth.instance;
    final user = resolvedAuth.currentUser;
    if (user == null) {
      throw StateError('Remote sleep sync requires an authenticated user.');
    }
    final service = SleepRemoteSyncService(
      familyRepository: familyRepository,
      userId: user.uid,
      deviceId: deviceId,
      tokenStore: FirestoreSleepRemoteTokenStore(
        firestore ?? FirebaseFirestore.instance,
      ),
      messaging: FirebaseRemoteMessagingTokenSource(
        messaging ?? FirebaseMessaging.instance,
      ),
      activityKitTokens: MethodChannelActivityKitTokenSource(),
      userIdChanges: resolvedAuth
          .userChanges()
          .map((user) => user?.uid)
          .distinct(),
    );
    await service.start();
    return service;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _repo.addListener(_handleRepositoryChanged);

    _subscriptions.add(
      _userIdChanges.listen(
        (userId) => unawaited(_handleUserIdChanged(userId)),
      ),
    );
    _subscriptions.add(
      _messaging.onTokenRefresh.listen(
        (token) => unawaited(_handleTokenRefresh(token)),
      ),
    );
    _subscriptions.add(
      _messaging.foregroundMessages.listen(
        (data) => unawaited(handleSleepRemoteMessage(data)),
      ),
    );
    _subscriptions.add(
      _activityKitTokens.updates.listen(_handleActivityKitToken),
    );

    final loaded = await _tryLoadInitialToken();
    await _upsertCurrentDevice();
    if (!loaded && _initialTokenRetryDelays.isNotEmpty) {
      unawaited(_retryInitialToken());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _repo.removeListener(_handleRepositoryChanged);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _activityKitTokens.dispose();
  }

  void _handleRepositoryChanged() {
    unawaited(_upsertCurrentDevice());
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (_disposed || token.isEmpty) return;
    _tokenRevision += 1;
    _fcmToken = token;
    await _upsertCurrentDevice();
  }

  Future<void> _handleUserIdChanged(String? userId) async {
    if (_disposed || _userId == userId) return;
    _userId = userId;
    if (userId != null && userId.isNotEmpty) {
      await _upsertCurrentDevice();
    }
  }

  Future<bool> _tryLoadInitialToken() async {
    final revision = _tokenRevision;
    try {
      if (_platform == 'ios') {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) return false;
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return false;
      if (revision == _tokenRevision) {
        _fcmToken = token;
      }
      return true;
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[sleep-sync] FCM token is not ready; refresh/retry remains active.',
        );
      }
      return false;
    }
  }

  Future<void> _retryInitialToken() async {
    for (final retryDelay in _initialTokenRetryDelays) {
      await _delay(retryDelay);
      if (_disposed || _fcmToken != null) return;
      if (await _tryLoadInitialToken()) {
        await _upsertCurrentDevice();
        return;
      }
    }
  }

  Future<void> _upsertCurrentDevice() async {
    final familyId = _repo.state.familyId;
    final userId = _userId;
    if (familyId.isEmpty || userId == null || userId.isEmpty) return;
    await _tokenStore.upsertDevice(
      userId: userId,
      deviceId: _deviceId,
      familyId: familyId,
      platform: _platform,
      fcmToken: _fcmToken,
    );
  }

  Future<void> _handleActivityKitToken(ActivityKitTokenUpdate update) async {
    final familyId = _repo.state.familyId;
    final userId = _userId;
    if (familyId.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        update.token.isEmpty) {
      return;
    }
    switch (update.kind) {
      case ActivityKitTokenKind.pushToStart:
        await _tokenStore.saveActivityKitPushToStartToken(
          userId: userId,
          deviceId: _deviceId,
          familyId: familyId,
          token: update.token,
        );
      case ActivityKitTokenKind.activityUpdate:
        final eventId = update.eventId;
        if (eventId == null || eventId.isEmpty) return;
        await _tokenStore.saveActivityKitUpdateToken(
          userId: userId,
          deviceId: _deviceId,
          familyId: familyId,
          eventId: eventId,
          token: update.token,
        );
    }
  }

  static String _platformName() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'unknown',
  };
}

class FirestoreSleepRemoteTokenStore implements SleepRemoteTokenStore {
  FirestoreSleepRemoteTokenStore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection('users').doc(userId);

  DocumentReference<Map<String, dynamic>> _deviceRef(
    String userId,
    String deviceId,
  ) => _userRef(userId).collection('devices').doc(deviceId);

  @override
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String familyId,
    required String platform,
    required String? fcmToken,
  }) async {
    final batch = _firestore.batch();
    batch.set(_userRef(userId), {
      'id': userId,
      'currentFamilyId': familyId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_deviceRef(userId, deviceId), {
      'id': deviceId,
      'userId': userId,
      'familyId': familyId,
      'platform': platform,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Future<void> saveActivityKitPushToStartToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String token,
  }) async {
    await _deviceRef(userId, deviceId).set({
      'id': deviceId,
      'userId': userId,
      'familyId': familyId,
      'platform': 'ios',
      'activityKitPushToStartToken': token,
      'activityKitEnabled': true,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'activityKitPushToStartUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveActivityKitUpdateToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String eventId,
    required String token,
  }) async {
    await _deviceRef(
      userId,
      deviceId,
    ).collection('activities').doc(eventId).set({
      'id': eventId,
      'eventId': eventId,
      'familyId': familyId,
      'userId': userId,
      'deviceId': deviceId,
      'updateToken': token,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FirebaseRemoteMessagingTokenSource implements RemoteMessagingTokenSource {
  FirebaseRemoteMessagingTokenSource(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getAPNSToken() => _messaging.getAPNSToken();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map((message) => message.data);
}

class MethodChannelActivityKitTokenSource implements ActivityKitTokenSource {
  MethodChannelActivityKitTokenSource({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.ruvixlabs.babyrelay/sleep_activity_tokens') {
    _channel.setMethodCallHandler(_handleCall);
  }

  final MethodChannel _channel;
  final StreamController<ActivityKitTokenUpdate> _controller =
      StreamController<ActivityKitTokenUpdate>.broadcast();

  @override
  Stream<ActivityKitTokenUpdate> get updates => _controller.stream;

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'activityKitToken') return;
    final args = call.arguments;
    if (args is! Map) return;
    final token = args['token'] as String?;
    final kind = args['kind'] as String?;
    if (token == null || kind == null || token.isEmpty) return;
    final eventId = args['eventId'] as String?;
    _controller.add(
      ActivityKitTokenUpdate(
        kind: kind == 'pushToStart'
            ? ActivityKitTokenKind.pushToStart
            : ActivityKitTokenKind.activityUpdate,
        token: token,
        eventId: eventId,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }
}
