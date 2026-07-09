import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:babyrelay/domain/services/sleep_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SleepSummaryService();

  test('ongoing sleep appears in the daily summary immediately', () {
    final now = DateTime(2026, 6, 23, 23, 27, 30);
    final child = BabyProfile(
      id: 'mae',
      nickname: 'Mae',
      dob: now.subtract(const Duration(days: 180)),
      wakeTimeMinutes: 7 * 60,
      bedtimeMinutes: 19 * 60,
      napsPerDayEstimate: 3,
    );
    final sleep = CareEvent(
      id: 'sleep-1',
      childId: child.id,
      type: CareEventType.sleep,
      startAt: now.subtract(const Duration(seconds: 20)),
      loggedById: 'sara',
    );

    final summary = service.summarizeDay(
      child: child,
      events: [sleep],
      now: now,
    );

    expect(summary.hasSleepData, isTrue);
    expect(summary.ongoingSleep, sleep);
    expect(summary.primaryLabel, 'LIVE · now');
    expect(summary.totalMinutes, 0);
  });
}
