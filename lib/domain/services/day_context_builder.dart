import '../engine/sleep_prediction_engine.dart';
import '../models/care_event.dart';
import '../models/baby_profile.dart';

/// Derives the engine's day context from raw events so Today, Handoff, and
/// tests all agree on what counts as "a nap today".
class DayContextBuilder {
  const DayContextBuilder();

  /// Day sleep = a sleep that starts between 6:00 and 19:00.
  bool isDaySleep(CareEvent e) =>
      e.isSleep && e.startAt.hour >= 6 && e.startAt.hour < 19;

  List<CompletedNap> napsToday(List<CareEvent> events, DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    return events
        .where(
          (e) =>
              isDaySleep(e) &&
              e.endAt != null &&
              !e.startAt.isBefore(dayStart) &&
              e.startAt.isBefore(now.add(const Duration(days: 1))),
        )
        .map(
          (e) =>
              CompletedNap(endedAt: e.endAt!, minutes: e.duration!.inMinutes),
        )
        .toList()
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
  }

  /// When the baby last woke today, or null if no completed sleep yet.
  DateTime? lastWakeAt(List<CareEvent> events, DateTime now) {
    final naps = napsToday(events, now);
    if (naps.isEmpty) return null;
    return naps.last.endedAt;
  }

  SleepDayContext build({
    required BabyProfile baby,
    required List<CareEvent> events,
    required DateTime now,
    List<int> recentNapCounts = const [],
    bool assumeAwakeNow = false,
  }) {
    final naps = napsToday(events, now);
    return SleepDayContext(
      now: now,
      ageInWeeks: baby.ageInWeeksAt(now),
      napsToday: naps,
      lastWakeAt: assumeAwakeNow ? now : lastWakeAt(events, now),
      wakeTimeMinutes: baby.wakeTimeMinutes,
      bedtimeMinutes: baby.bedtimeMinutes,
      recentNapCounts: recentNapCounts,
      scheduleOverrideNaps: baby.scheduleOverrideNaps,
    );
  }
}
