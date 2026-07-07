import 'dart:async';

import 'package:babyrelay/core/sleep/sleep_remote_sync_service.dart';
import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<FamilyRepository> onboardedRepo() async {
    final repo = FamilyRepository(InMemoryStore(), deviceId: 'device_a');
    await repo.completeOnboarding(
      firstChild: BabyProfile(
        id: '',
        nickname: 'Mae',
        dob: DateTime.now().subtract(const Duration(days: 180)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60,
        napsPerDayEstimate: 3,
      ),
      primaryCaregiverName: 'Sara',
    );
    return repo;
  }

  test('registers current device and refreshes FCM token', () async {
    final repo = await onboardedRepo();
    final store = _FakeTokenStore();
    final messaging = _FakeMessagingSource(initialToken: 'fcm_a');
    final activity = _FakeActivityKitTokenSource();
    final service = SleepRemoteSyncService(
      familyRepository: repo,
      userId: 'user_a',
      deviceId: 'device_a',
      tokenStore: store,
      messaging: messaging,
      activityKitTokens: activity,
      platform: 'ios',
    );

    await service.start();
    expect(store.deviceWrites, hasLength(1));
    expect(store.deviceWrites.single.fcmToken, 'fcm_a');
    expect(store.deviceWrites.single.familyId, repo.state.familyId);

    messaging.emitToken('fcm_b');
    await _drainAsync();

    expect(store.deviceWrites, hasLength(2));
    expect(store.deviceWrites.last.fcmToken, 'fcm_b');

    await service.dispose();
  });

  test('uploads ActivityKit push-to-start and update tokens', () async {
    final repo = await onboardedRepo();
    final store = _FakeTokenStore();
    final messaging = _FakeMessagingSource(initialToken: 'fcm_a');
    final activity = _FakeActivityKitTokenSource();
    final service = SleepRemoteSyncService(
      familyRepository: repo,
      userId: 'user_a',
      deviceId: 'device_a',
      tokenStore: store,
      messaging: messaging,
      activityKitTokens: activity,
      platform: 'ios',
    );

    await service.start();
    activity.emit(
      const ActivityKitTokenUpdate(
        kind: ActivityKitTokenKind.pushToStart,
        token: 'start_token',
      ),
    );
    activity.emit(
      const ActivityKitTokenUpdate(
        kind: ActivityKitTokenKind.activityUpdate,
        token: 'update_token',
        eventId: 'sleep_1',
      ),
    );
    await _drainAsync();

    expect(store.pushToStartTokens.single.token, 'start_token');
    expect(store.updateTokens.single.eventId, 'sleep_1');
    expect(store.updateTokens.single.token, 'update_token');

    await service.dispose();
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _DeviceWrite {
  const _DeviceWrite({
    required this.userId,
    required this.deviceId,
    required this.familyId,
    required this.platform,
    required this.fcmToken,
  });

  final String userId;
  final String deviceId;
  final String familyId;
  final String platform;
  final String? fcmToken;
}

class _ActivityTokenWrite {
  const _ActivityTokenWrite({
    required this.userId,
    required this.deviceId,
    required this.familyId,
    required this.token,
    this.eventId,
  });

  final String userId;
  final String deviceId;
  final String familyId;
  final String token;
  final String? eventId;
}

class _FakeTokenStore implements SleepRemoteTokenStore {
  final deviceWrites = <_DeviceWrite>[];
  final pushToStartTokens = <_ActivityTokenWrite>[];
  final updateTokens = <_ActivityTokenWrite>[];

  @override
  Future<void> upsertDevice({
    required String userId,
    required String deviceId,
    required String familyId,
    required String platform,
    required String? fcmToken,
  }) async {
    deviceWrites.add(
      _DeviceWrite(
        userId: userId,
        deviceId: deviceId,
        familyId: familyId,
        platform: platform,
        fcmToken: fcmToken,
      ),
    );
  }

  @override
  Future<void> saveActivityKitPushToStartToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String token,
  }) async {
    pushToStartTokens.add(
      _ActivityTokenWrite(
        userId: userId,
        deviceId: deviceId,
        familyId: familyId,
        token: token,
      ),
    );
  }

  @override
  Future<void> saveActivityKitUpdateToken({
    required String userId,
    required String deviceId,
    required String familyId,
    required String eventId,
    required String token,
  }) async {
    updateTokens.add(
      _ActivityTokenWrite(
        userId: userId,
        deviceId: deviceId,
        familyId: familyId,
        eventId: eventId,
        token: token,
      ),
    );
  }
}

class _FakeMessagingSource implements RemoteMessagingTokenSource {
  _FakeMessagingSource({required this.initialToken});

  final String initialToken;
  final _tokenController = StreamController<String>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<String?> getToken() async => initialToken;

  @override
  Stream<String> get onTokenRefresh => _tokenController.stream;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages =>
      _messageController.stream;

  void emitToken(String token) => _tokenController.add(token);
}

class _FakeActivityKitTokenSource implements ActivityKitTokenSource {
  final _controller = StreamController<ActivityKitTokenUpdate>.broadcast();

  @override
  Stream<ActivityKitTokenUpdate> get updates => _controller.stream;

  void emit(ActivityKitTokenUpdate update) => _controller.add(update);

  @override
  Future<void> dispose() => _controller.close();
}
