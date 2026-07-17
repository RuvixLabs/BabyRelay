import 'dart:async';

import 'package:babyrelay/core/sleep/sleep_runtime_service.dart';
import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:babyrelay/domain/models/caregiver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<FamilyRepository> onboardedRepo() async {
    final repo = FamilyRepository(InMemoryStore());
    await repo.completeOnboarding(
      firstChild: BabyProfile(
        id: '',
        nickname: 'Mae',
        dob: DateTime.now().subtract(const Duration(days: 210)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60,
        napsPerDayEstimate: 3,
      ),
      primaryCaregiverName: 'Sara',
    );
    return repo;
  }

  test(
    'new live sleep requests permission and schedules runtime surfaces',
    () async {
      final repo = await onboardedRepo();
      final platform = _FakeSleepRuntimePlatform();
      final service = RepositorySleepRuntimeService(
        familyRepository: repo,
        platform: platform,
        alertPolicy: const LongSleepAlertPolicy(
          daySleepThreshold: Duration(minutes: 10),
          nightSleepThreshold: Duration(minutes: 10),
        ),
      );

      await service.start();
      final startAt = DateTime.now().subtract(const Duration(minutes: 2));
      final sleep = await repo.startSleep(at: startAt);
      await _drainAsyncListener();

      expect(sleep, isNotNull);
      expect(platform.permissionRequests, 1);
      expect(platform.scheduledAlerts, hasLength(1));
      expect(platform.scheduledAlerts.single.childName, 'Mae');
      expect(
        platform.scheduledAlerts.single.fireAt.difference(startAt).inMinutes,
        10,
      );
      expect(platform.ongoingSleep?.eventId, sleep!.id);
      expect(platform.liveActivity?.eventId, sleep.id);

      await service.dispose();
    },
  );

  test(
    'shared sleep alert opt-in requests permission before a sleep',
    () async {
      final repo = await onboardedRepo();
      final platform = _FakeSleepRuntimePlatform();
      final service = RepositorySleepRuntimeService(
        familyRepository: repo,
        platform: platform,
      );

      await service.start();
      final granted = await service.requestSharedSleepAlerts();

      expect(granted, isTrue);
      expect(platform.permissionRequests, 1);
      await service.dispose();
    },
  );

  test('ending sleep cancels scheduled alert and live surfaces', () async {
    final repo = await onboardedRepo();
    final platform = _FakeSleepRuntimePlatform();
    final service = RepositorySleepRuntimeService(
      familyRepository: repo,
      platform: platform,
      alertPolicy: const LongSleepAlertPolicy(
        daySleepThreshold: Duration(minutes: 10),
        nightSleepThreshold: Duration(minutes: 10),
      ),
    );

    await service.start();
    await repo.startSleep(
      at: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    await _drainAsyncListener();
    expect(platform.scheduledAlerts, hasLength(1));

    await repo.endSleep();
    await _drainAsyncListener();

    expect(
      platform.cancelledAlertIds,
      contains(platform.scheduledAlerts.single.id),
    );
    expect(platform.ongoingCancelled, isTrue);
    expect(platform.liveEnded, isTrue);

    await service.dispose();
  });

  test(
    'startup with already-running sleep refreshes live surfaces without prompting',
    () async {
      final repo = await onboardedRepo();
      final sleep = await repo.startSleep(
        at: DateTime.now().subtract(const Duration(minutes: 12)),
      );
      final platform = _FakeSleepRuntimePlatform();
      final service = RepositorySleepRuntimeService(
        familyRepository: repo,
        platform: platform,
        alertPolicy: const LongSleepAlertPolicy(
          daySleepThreshold: Duration(hours: 1),
          nightSleepThreshold: Duration(hours: 1),
        ),
      );

      await service.start();

      expect(platform.permissionRequests, 0);
      expect(platform.ongoingSleep?.eventId, sleep!.id);
      expect(platform.liveActivity?.eventId, sleep.id);

      await service.dispose();
    },
  );

  test('synced remote sleep starts caregiver runtime surfaces', () async {
    final sync = _FakeFamilySyncAdapter();
    final repo = FamilyRepository(InMemoryStore(), sync: sync);
    await repo.completeOnboarding(
      firstChild: BabyProfile(
        id: '',
        nickname: 'Mae',
        dob: DateTime.now().subtract(const Duration(days: 210)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60,
        napsPerDayEstimate: 3,
      ),
      primaryCaregiverName: 'Nana',
    );
    final platform = _FakeSleepRuntimePlatform();
    final service = RepositorySleepRuntimeService(
      familyRepository: repo,
      platform: platform,
      alertPolicy: const LongSleepAlertPolicy(
        daySleepThreshold: Duration(minutes: 10),
        nightSleepThreshold: Duration(minutes: 10),
      ),
    );

    await service.start();
    final remoteSleep = CareEvent(
      id: 'remote_sleep',
      childId: repo.state.selectedChildId,
      type: CareEventType.sleep,
      startAt: DateTime.now().subtract(const Duration(minutes: 3)),
      loggedById: 'owner_uid',
    );
    sync.emitRemote(repo.state.copyWith(events: [remoteSleep]));
    await _drainAsyncListener();

    expect(
      repo.state.events.map((event) => event.id),
      contains('remote_sleep'),
    );
    expect(platform.permissionRequests, 1);
    expect(platform.ongoingSleep?.eventId, 'remote_sleep');
    expect(platform.liveActivity?.eventId, 'remote_sleep');
    expect(platform.liveActivity?.activeSleepSummary, 'Mae sleeping');

    await service.dispose();
  });

  test('multiple children surface count and child summary', () async {
    final repo = await onboardedRepo();
    final maeId = repo.state.selectedChildId;
    final theo = await repo.addChild(
      BabyProfile(
        id: '',
        nickname: 'Theo',
        dob: DateTime.now().subtract(const Duration(days: 480)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60 + 30,
        napsPerDayEstimate: 1,
      ),
    );
    final platform = _FakeSleepRuntimePlatform();
    final service = RepositorySleepRuntimeService(
      familyRepository: repo,
      platform: platform,
      alertPolicy: const LongSleepAlertPolicy(
        daySleepThreshold: Duration(minutes: 10),
        nightSleepThreshold: Duration(minutes: 10),
      ),
    );

    await service.start();
    await repo.startSleep(
      childId: maeId,
      at: DateTime.now().subtract(const Duration(minutes: 8)),
    );
    await repo.startSleep(
      childId: theo.id,
      at: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    await _drainAsyncListener();

    expect(platform.ongoingSleep?.activeSleepCount, 2);
    expect(platform.liveActivity?.activeSleepCount, 2);
    expect(platform.liveActivity?.activeSleepSummary, 'Mae + Theo sleeping');
    expect(platform.liveActivity?.childName, 'Theo');

    await service.dispose();
  });
}

Future<void> _drainAsyncListener() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _ScheduledAlert {
  const _ScheduledAlert({
    required this.id,
    required this.childName,
    required this.fireAt,
  });

  final int id;
  final String childName;
  final DateTime fireAt;
}

class _LiveSurface {
  const _LiveSurface({
    required this.eventId,
    required this.childName,
    required this.startedAt,
    required this.activeSleepCount,
    required this.activeSleepSummary,
  });

  final String eventId;
  final String childName;
  final DateTime startedAt;
  final int activeSleepCount;
  final String activeSleepSummary;
}

class _FakeSleepRuntimePlatform implements SleepRuntimePlatform {
  int permissionRequests = 0;
  final scheduledAlerts = <_ScheduledAlert>[];
  final cancelledAlertIds = <int>[];
  _LiveSurface? ongoingSleep;
  _LiveSurface? liveActivity;
  bool ongoingCancelled = false;
  bool liveEnded = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestNotificationPermissions() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<void> scheduleLongSleepAlert({
    required int id,
    required String childName,
    required DateTime fireAt,
    required Duration elapsed,
  }) async {
    scheduledAlerts.add(
      _ScheduledAlert(id: id, childName: childName, fireAt: fireAt),
    );
  }

  @override
  Future<void> cancelLongSleepAlert(int id) async {
    cancelledAlertIds.add(id);
  }

  @override
  Future<void> showOngoingSleep({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
    required String activeSleepSummary,
  }) async {
    ongoingCancelled = false;
    ongoingSleep = _LiveSurface(
      eventId: eventId,
      childName: childName,
      startedAt: startedAt,
      activeSleepCount: activeSleepCount,
      activeSleepSummary: activeSleepSummary,
    );
  }

  @override
  Future<void> cancelOngoingSleep() async {
    ongoingCancelled = true;
    ongoingSleep = null;
  }

  @override
  Future<void> startOrUpdateLiveActivity({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
    required String activeSleepSummary,
  }) async {
    liveEnded = false;
    liveActivity = _LiveSurface(
      eventId: eventId,
      childName: childName,
      startedAt: startedAt,
      activeSleepCount: activeSleepCount,
      activeSleepSummary: activeSleepSummary,
    );
  }

  @override
  Future<void> endLiveActivity() async {
    liveEnded = true;
    liveActivity = null;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeFamilySyncAdapter implements FamilySyncAdapter {
  @override
  String get userId => 'caregiver_uid';

  final _controller = StreamController<FamilyState>.broadcast();
  int _familyCounter = 0;

  @override
  String newFamilyId() => 'family_${++_familyCounter}';

  @override
  Stream<FamilyState> watchFamily(String familyId) => _controller.stream;

  @override
  Future<void> saveFamily(
    FamilyState state, {
    String? previousInviteCode,
  }) async {}

  void emitRemote(FamilyState state) => _controller.add(state);

  @override
  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCurrentUserRemoteData(FamilyState state) async {}

  @override
  Future<bool> deleteCurrentAuthIdentity() async => true;

  @override
  Future<void> dispose() => _controller.close();
}
