import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/family_repository.dart';
import '../../domain/models/care_event.dart';
import '../analytics/analytics_service.dart';
import '../util/formats.dart';

abstract class SleepRuntimeService {
  Future<void> dispose();

  static SleepRuntimeService disabled() => _DisabledSleepRuntimeService();

  static Future<SleepRuntimeService> create({
    required FamilyRepository familyRepository,
    required AnalyticsService analytics,
  }) async {
    final platform = await FlutterSleepRuntimePlatform.create(analytics);
    final service = RepositorySleepRuntimeService(
      familyRepository: familyRepository,
      platform: platform,
    );
    await service.start();
    return service;
  }
}

@visibleForTesting
class RepositorySleepRuntimeService implements SleepRuntimeService {
  RepositorySleepRuntimeService({
    required FamilyRepository familyRepository,
    required SleepRuntimePlatform platform,
    LongSleepAlertPolicy alertPolicy = const LongSleepAlertPolicy(),
  }) : _repo = familyRepository,
       _platform = platform,
       _alertPolicy = alertPolicy;

  final FamilyRepository _repo;
  final SleepRuntimePlatform _platform;
  final LongSleepAlertPolicy _alertPolicy;
  final Set<String> _scheduledAlertEventIds = {};
  String? _liveEventId;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _platform.initialize();
    _repo.addListener(_handleRepositoryChanged);
    await _syncRuntimeState(requestPermissionForNewSleeps: false);
  }

  void _handleRepositoryChanged() {
    unawaited(_syncRuntimeState(requestPermissionForNewSleeps: true));
  }

  Future<void> _syncRuntimeState({
    required bool requestPermissionForNewSleeps,
  }) async {
    final family = _repo.state;
    final ongoing =
        family.events.where((event) => event.isOngoingSleep).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final ongoingIds = ongoing.map((event) => event.id).toSet();
    final newOngoing = ongoingIds.difference(_scheduledAlertEventIds);
    final shouldRequestPermission =
        requestPermissionForNewSleeps && newOngoing.isNotEmpty;
    final hasNotificationPermission = shouldRequestPermission
        ? await _platform.requestNotificationPermissions()
        : true;

    for (final staleId in _scheduledAlertEventIds.difference(ongoingIds)) {
      await _platform.cancelLongSleepAlert(_notificationIdFor(staleId));
      _scheduledAlertEventIds.remove(staleId);
    }

    for (final sleep in ongoing) {
      if (_scheduledAlertEventIds.contains(sleep.id)) continue;
      final child = family.childById(sleep.childId);
      final alertAt = _alertPolicy.alertAt(sleep);
      if (child == null ||
          alertAt == null ||
          !alertAt.isAfter(DateTime.now())) {
        continue;
      }
      if (hasNotificationPermission) {
        await _platform.scheduleLongSleepAlert(
          id: _notificationIdFor(sleep.id),
          childName: child.nickname,
          fireAt: alertAt,
          elapsed: alertAt.difference(sleep.startAt),
        );
      }
      _scheduledAlertEventIds.add(sleep.id);
    }

    final liveSleep =
        family.ongoingSleep ?? (ongoing.isEmpty ? null : ongoing.last);
    if (liveSleep == null) {
      if (_liveEventId != null) {
        await _platform.cancelOngoingSleep();
        await _platform.endLiveActivity();
        _liveEventId = null;
      }
      return;
    }

    final liveChild = family.childById(liveSleep.childId);
    if (liveChild == null) return;
    _liveEventId = liveSleep.id;
    await _platform.showOngoingSleep(
      eventId: liveSleep.id,
      childName: liveChild.nickname,
      startedAt: liveSleep.startAt,
      activeSleepCount: ongoing.length,
    );
    await _platform.startOrUpdateLiveActivity(
      eventId: liveSleep.id,
      childName: liveChild.nickname,
      startedAt: liveSleep.startAt,
      activeSleepCount: ongoing.length,
    );
  }

  @override
  Future<void> dispose() async {
    _repo.removeListener(_handleRepositoryChanged);
    await _platform.dispose();
  }

  int _notificationIdFor(String eventId) {
    var hash = 0x811c9dc5;
    for (final unit in eventId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 10000 + (hash % 500000);
  }
}

@visibleForTesting
class LongSleepAlertPolicy {
  const LongSleepAlertPolicy({
    this.daySleepThreshold = const Duration(hours: 2, minutes: 15),
    this.nightSleepThreshold = const Duration(hours: 12),
  });

  final Duration daySleepThreshold;
  final Duration nightSleepThreshold;

  DateTime? alertAt(CareEvent sleep) {
    if (!sleep.isOngoingSleep) return null;
    final startedDuringDay = sleep.startAt.hour >= 6 && sleep.startAt.hour < 19;
    final threshold = startedDuringDay
        ? daySleepThreshold
        : nightSleepThreshold;
    return sleep.startAt.add(threshold);
  }
}

@visibleForTesting
abstract class SleepRuntimePlatform {
  Future<void> initialize();

  Future<bool> requestNotificationPermissions();

  Future<void> scheduleLongSleepAlert({
    required int id,
    required String childName,
    required DateTime fireAt,
    required Duration elapsed,
  });

  Future<void> cancelLongSleepAlert(int id);

  Future<void> showOngoingSleep({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
  });

  Future<void> cancelOngoingSleep();

  Future<void> startOrUpdateLiveActivity({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
  });

  Future<void> endLiveActivity();

  Future<void> dispose();
}

class FlutterSleepRuntimePlatform implements SleepRuntimePlatform {
  FlutterSleepRuntimePlatform._(this._notifications, this._analytics);

  static const _ongoingNotificationId = 7601;
  static const _activityChannel = MethodChannel(
    'com.ruvixlabs.babyrelay/sleep_activity',
  );

  final FlutterLocalNotificationsPlugin _notifications;
  final AnalyticsService _analytics;

  static Future<FlutterSleepRuntimePlatform> create(
    AnalyticsService analytics,
  ) async {
    return FlutterSleepRuntimePlatform._(
      FlutterLocalNotificationsPlugin(),
      analytics,
    );
  }

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // The plugin can fail on unsupported test hosts. Device builds still use
      // the real local timezone; this fallback keeps scheduling non-fatal.
    }

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_sleep'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        _analytics.logEvent('notification_tapped', {
          'type': response.payload ?? 'sleep',
        });
      },
    );
  }

  @override
  Future<bool> requestNotificationPermissions() async {
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosGranted =
        await ios?.requestPermissions(alert: true, sound: true) ?? true;
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    final granted = iosGranted && androidGranted;
    if (granted) {
      _analytics.logEvent('notification_enabled', {'type': 'sleep'});
    }
    return granted;
  }

  @override
  Future<void> scheduleLongSleepAlert({
    required int id,
    required String childName,
    required DateTime fireAt,
    required Duration elapsed,
  }) async {
    final scheduled = tz.TZDateTime.from(fireAt, tz.local);
    await _notifications.zonedSchedule(
      id: id,
      title: '$childName may be ready to wake',
      body:
          'This sleep has been running ${formatDurationMinutes(elapsed.inMinutes)}.',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_alerts',
          'Sleep alerts',
          channelDescription: 'Helpful nudges when a nap is running long.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'sleep_alert',
    );
  }

  @override
  Future<void> cancelLongSleepAlert(int id) => _notifications.cancel(id: id);

  @override
  Future<void> showOngoingSleep({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final title = activeSleepCount > 1
        ? '$activeSleepCount sleep timers running'
        : '$childName is sleeping';
    await _notifications.show(
      id: _ongoingNotificationId,
      title: title,
      body: 'Started ${formatTime(startedAt)}. Tap to reopen BabyRelay.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sleep_live',
          'Live sleep timer',
          channelDescription: 'Persistent timer while sleep is being tracked.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          silent: true,
          onlyAlertOnce: true,
          showWhen: true,
          when: startedAt.millisecondsSinceEpoch,
          usesChronometer: true,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: 'sleep_live',
    );
  }

  @override
  Future<void> cancelOngoingSleep() =>
      _notifications.cancel(id: _ongoingNotificationId);

  @override
  Future<void> startOrUpdateLiveActivity({
    required String eventId,
    required String childName,
    required DateTime startedAt,
    required int activeSleepCount,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _activityChannel.invokeMethod<void>('startOrUpdate', {
        'eventId': eventId,
        'childName': childName,
        'startedAtMillis': startedAt.millisecondsSinceEpoch,
        'activeSleepCount': activeSleepCount,
      });
    } catch (_) {
      // ActivityKit is unavailable on older iOS versions and in some simulator
      // contexts. The in-app timer and local notifications remain functional.
    }
  }

  @override
  Future<void> endLiveActivity() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _activityChannel.invokeMethod<void>('end');
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {}
}

class _DisabledSleepRuntimeService implements SleepRuntimeService {
  @override
  Future<void> dispose() async {}
}
