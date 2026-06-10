import 'package:babyrelay/domain/engine/sleep_prediction_engine.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:babyrelay/domain/services/handoff_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = HandoffService();
  final day = DateTime(2026, 6, 10);

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  CareEvent sleep(
    String id,
    DateTime start,
    DateTime? end, {
    String by = 'u1',
  }) => CareEvent(
    id: id,
    type: CareEventType.sleep,
    startAt: start,
    endAt: end,
    loggedById: by,
  );

  final caregivers = {'u1': 'Sara', 'u2': 'Sam'};

  test('awake summary mirrors the plan example shape', () {
    final events = [
      sleep('s1', at(9), at(10, 10)),
      sleep('s2', at(14, 5), at(14, 45), by: 'u2'),
      CareEvent(
        id: 'n1',
        type: CareEventType.note,
        startAt: at(10, 30),
        loggedById: 'u1',
        note: 'Bottle finished before nap.',
      ),
    ];
    final prediction = NextUpPrediction(
      kind: NextUpKind.nap,
      windowStart: at(16, 20),
      windowEnd: at(16, 50),
      explanation: 'Typical wake window.',
      wakeWindowMinutes: 120,
      napsExpected: 3,
    );

    final summary = service.build(
      babyName: 'Mae',
      now: at(15),
      todayEvents: events,
      caregiverNames: caregivers,
      prediction: prediction,
    );

    expect(summary.statusLine, 'Mae woke at 2:45 pm from a 40 min nap.');
    expect(
      summary.lines,
      contains('2 naps so far today, 1h 50m of day sleep.'),
    );
    expect(
      summary.lines,
      contains('Next nap window opens around 4:20 pm–4:50 pm.'),
    );
    expect(
      summary.headsUp.first,
      'Last note from Sara: "Bottle finished before nap."',
    );
    expect(summary.shareText, contains('Handoff for Mae'));
    expect(summary.shareText, contains('Sent with BabyRelay'));
  });

  test('asleep status counts elapsed time', () {
    final events = [sleep('s1', at(14, 5), null)];
    final summary = service.build(
      babyName: 'Mae',
      now: at(14, 43),
      todayEvents: events,
      caregiverNames: caregivers,
    );
    expect(
      summary.statusLine,
      'Mae is asleep — went down at 2:05 pm (38 min so far).',
    );
  });

  test('empty day is handled gracefully', () {
    final summary = service.build(
      babyName: 'Mae',
      now: at(9),
      todayEvents: const [],
      caregiverNames: caregivers,
    );
    expect(
      summary.statusLine,
      'Mae has been awake since this morning — no sleep logged yet.',
    );
    expect(summary.lines, contains('No naps logged yet today.'));
    expect(summary.headsUp, contains('Nothing unusual flagged today.'));
  });

  test('feeds, diapers and night wakings appear with latest info', () {
    final events = [
      CareEvent(
        id: 'f1',
        type: CareEventType.feed,
        startAt: at(7, 30),
        loggedById: 'u1',
        feedKind: FeedKind.bottle,
      ),
      CareEvent(
        id: 'f2',
        type: CareEventType.feed,
        startAt: at(11, 0),
        loggedById: 'u2',
        feedKind: FeedKind.nursing,
      ),
      CareEvent(
        id: 'd1',
        type: CareEventType.diaper,
        startAt: at(12, 50),
        loggedById: 'u2',
        diaperKind: DiaperKind.wet,
      ),
      CareEvent(
        id: 'w1',
        type: CareEventType.nightWaking,
        startAt: at(3, 15),
        loggedById: 'u1',
      ),
    ];
    final summary = service.build(
      babyName: 'Mae',
      now: at(13),
      todayEvents: events,
      caregiverNames: caregivers,
    );
    expect(
      summary.lines,
      contains('Last feed: nursing at 11:00 am (2 feeds today).'),
    );
    expect(summary.lines, contains('Last diaper: wet at 12:50 pm.'));
    expect(summary.lines, contains('1 night waking logged.'));
  });

  test('bedtime prediction reads as bedtime', () {
    final prediction = NextUpPrediction(
      kind: NextUpKind.bedtime,
      windowStart: at(18, 45),
      windowEnd: at(19, 15),
      explanation: 'Last wake window of the day.',
      wakeWindowMinutes: 180,
      napsExpected: 3,
    );
    final summary = service.build(
      babyName: 'Mae',
      now: at(17),
      todayEvents: const [],
      caregiverNames: caregivers,
      prediction: prediction,
    );
    expect(summary.lines, contains('Aim for bedtime around 6:45 pm–7:15 pm.'));
  });
}
