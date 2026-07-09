import '../models/baby_profile.dart';
import '../models/care_event.dart';
import '../../core/util/formats.dart';

class DailySleepSummary {
  const DailySleepSummary({
    required this.dayStart,
    required this.dayEnd,
    required this.sleepEvents,
    required this.completedSleeps,
    required this.ongoingSleep,
    required this.totalMinutes,
    required this.daySleepMinutes,
    required this.nightSleepMinutes,
    required this.napCount,
    required this.longestSleepMinutes,
    required this.lastWakeAt,
    required this.now,
  });

  final DateTime dayStart;
  final DateTime dayEnd;
  final List<CareEvent> sleepEvents;
  final List<CareEvent> completedSleeps;
  final CareEvent? ongoingSleep;
  final int totalMinutes;
  final int daySleepMinutes;
  final int nightSleepMinutes;
  final int napCount;
  final int longestSleepMinutes;
  final DateTime? lastWakeAt;
  final DateTime now;

  bool get hasSleepData => sleepEvents.isNotEmpty;
  bool get isAsleep => ongoingSleep != null;

  int? get awakeMinutes {
    if (isAsleep) return null;
    final anchor = lastWakeAt;
    if (anchor == null) return null;
    return now.difference(anchor).inMinutes.clamp(0, 24 * 60);
  }

  int get averageNapMinutes =>
      napCount == 0 ? 0 : (daySleepMinutes / napCount).round();

  String get primaryLabel {
    if (ongoingSleep != null) {
      final minutes = now.difference(ongoingSleep!.startAt).inMinutes;
      return 'LIVE · ${formatDurationMinutes(minutes)}';
    }
    final awake = awakeMinutes;
    if (awake != null) {
      return '${formatDurationMinutes(awake)} awake';
    }
    if (totalMinutes > 0) {
      return '${formatDurationMinutes(totalMinutes)} logged';
    }
    return 'No sleep logged';
  }

  String get reassurance {
    if (ongoingSleep != null) {
      return 'Started at ${formatTime(ongoingSleep!.startAt)}. When your baby wakes, BabyRelay will recalculate the next window.';
    }
    if (lastWakeAt != null) {
      return 'Last wake was ${formatTime(lastWakeAt!)}. The next window uses this awake stretch.';
    }
    return 'Start the first sleep live, or add a nap afterward if someone forgot to tap.';
  }
}

class SleepSummaryService {
  const SleepSummaryService();

  DailySleepSummary summarizeDay({
    required BabyProfile child,
    required List<CareEvent> events,
    required DateTime now,
  }) {
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final sleeps =
        events
            .where(
              (event) =>
                  event.isSleep && _touchesRange(event, dayStart, dayEnd, now),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final completed = sleeps.where((event) => event.endAt != null).toList();
    CareEvent? ongoing;
    for (final sleep in sleeps) {
      if (sleep.isOngoingSleep) ongoing = sleep;
    }

    var total = 0;
    var day = 0;
    var night = 0;
    var longest = 0;
    for (final sleep in sleeps) {
      final minutes = _overlapMinutes(sleep, dayStart, dayEnd, now);
      total += minutes;
      if (_isDaySleep(sleep)) {
        day += minutes;
      } else {
        night += minutes;
      }
      if (minutes > longest) longest = minutes;
    }

    final lastWake = completed.isEmpty
        ? null
        : completed
              .map((event) => event.endAt!)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return DailySleepSummary(
      dayStart: dayStart,
      dayEnd: dayEnd,
      sleepEvents: sleeps,
      completedSleeps: completed,
      ongoingSleep: ongoing,
      totalMinutes: total,
      daySleepMinutes: day,
      nightSleepMinutes: night,
      napCount: sleeps.where(_isDaySleep).length,
      longestSleepMinutes: longest,
      lastWakeAt: lastWake,
      now: now,
    );
  }

  int _overlapMinutes(
    CareEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime now,
  ) {
    final endAt = event.endAt ?? now;
    final start = event.startAt.isAfter(rangeStart)
        ? event.startAt
        : rangeStart;
    final end = endAt.isBefore(rangeEnd) ? endAt : rangeEnd;
    if (!end.isAfter(start)) return 0;
    return end.difference(start).inMinutes;
  }

  bool _touchesRange(
    CareEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime now,
  ) {
    final endAt = event.endAt ?? now;
    final start = event.startAt.isAfter(rangeStart)
        ? event.startAt
        : rangeStart;
    final end = endAt.isBefore(rangeEnd) ? endAt : rangeEnd;
    return !end.isBefore(start);
  }

  bool _isDaySleep(CareEvent event) =>
      event.startAt.hour >= 6 && event.startAt.hour < 19;
}
