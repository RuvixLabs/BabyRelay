import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const int kRemoteSleepNotificationId = 7601;
const String kRemoteSleepMessageTypeKey = 'babyrelayType';
const String kRemoteSleepStartOrUpdateType = 'sleep_live_update';
const String kRemoteSleepEndType = 'sleep_live_end';

@pragma('vm:entry-point')
Future<void> babyRelayFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // If Firebase is already initialized in this isolate or unavailable during
    // a host-side test, the message handler can still safely fall through.
  }
  await handleSleepRemoteMessage(message.data);
}

Future<void> handleSleepRemoteMessage(Map<String, dynamic> data) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final type = data[kRemoteSleepMessageTypeKey] as String?;
  if (type != kRemoteSleepStartOrUpdateType && type != kRemoteSleepEndType) {
    return;
  }

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_sleep'),
    ),
  );

  if (type == kRemoteSleepEndType) {
    await notifications.cancel(id: kRemoteSleepNotificationId);
    return;
  }

  final childName = _stringValue(data['childName'], fallback: 'Baby');
  final summary = _stringValue(
    data['activeSleepSummary'],
    fallback: '$childName sleeping',
  );
  final activeSleepCount =
      int.tryParse('${data['activeSleepCount'] ?? 1}') ?? 1;
  final startedAtMillis =
      int.tryParse('${data['startedAtMillis'] ?? 0}') ??
      DateTime.now().millisecondsSinceEpoch;
  final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);

  final title = activeSleepCount > 1
      ? '$activeSleepCount sleep timers running'
      : '$childName is sleeping';
  final body = activeSleepCount > 1
      ? summary
      : 'Started ${_formatTime(startedAt)}. Tap to reopen BabyRelay.';

  await notifications.show(
    id: kRemoteSleepNotificationId,
    title: title,
    body: body,
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

String _stringValue(Object? value, {required String fallback}) {
  final text = value?.toString();
  return text == null || text.isEmpty ? fallback : text;
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
