import 'package:babyrelay/domain/engine/sleep_prediction_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SleepPredictionEngine();
  final day = DateTime(2026, 6, 10);

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  SleepDayContext ctx({
    int ageInWeeks = 30, // 6-9 months band: 3 naps, 135-180 min windows
    List<CompletedNap> naps = const [],
    DateTime? lastWakeAt,
    DateTime? now,
    int drift = 0,
    List<int> recentNapCounts = const [],
    int? override,
    int bedtimeMinutes = 19 * 60,
  }) {
    return SleepDayContext(
      now: now ?? at(10),
      ageInWeeks: ageInWeeks,
      napsToday: naps,
      lastWakeAt: lastWakeAt,
      wakeTimeMinutes: 7 * 60,
      bedtimeMinutes: bedtimeMinutes,
      personalDriftMinutes: drift,
      recentNapCounts: recentNapCounts,
      scheduleOverrideNaps: override,
    );
  }

  group('age bands', () {
    test('selects the right band per age', () {
      expect(engine.bandFor(4).label, 'newborn');
      expect(engine.bandFor(12).label, '3–6 months');
      expect(engine.bandFor(30).label, '6–9 months');
      expect(engine.bandFor(45).label, '9–14 months');
      expect(engine.bandFor(70).label, '14–24 months');
      expect(engine.bandFor(500).label, '14–24 months');
    });

    test('expected naps follows table and override wins', () {
      expect(engine.expectedNaps(4), 5);
      expect(engine.expectedNaps(30), 3);
      expect(engine.expectedNaps(30, override: 2), 2);
    });
  });

  group('wake windows', () {
    test('first window of the day uses the band minimum', () {
      expect(engine.wakeWindowMinutes(30, 0), 135);
    });

    test('last window of the day uses the band maximum', () {
      expect(engine.wakeWindowMinutes(30, 3), 180);
    });

    test('windows interpolate across the day', () {
      final w1 = engine.wakeWindowMinutes(30, 1);
      expect(w1, 150); // 135 + (180-135) * 1/3
    });
  });

  group('predict — naps', () {
    test('first nap anchors on morning wake time when nothing logged', () {
      final p = engine.predict(ctx(now: at(8)));
      // 7:00 wake + 135 min = 9:15, window ±15 min.
      expect(p.kind, NextUpKind.nap);
      expect(p.windowStart, at(9, 0));
      expect(p.windowEnd, at(9, 30));
    });

    test('next nap anchors on last wake', () {
      final p = engine.predict(
        ctx(
          naps: [CompletedNap(endedAt: at(10), minutes: 70)],
          lastWakeAt: at(10),
          now: at(10, 5),
        ),
      );
      // 10:00 + 150 min = 12:30.
      expect(p.windowStart, at(12, 15));
      expect(p.windowEnd, at(12, 45));
      expect(p.shortNapAdjusted, isFalse);
    });

    test('short nap shrinks the next window by 17.5%', () {
      final p = engine.predict(
        ctx(
          naps: [CompletedNap(endedAt: at(10), minutes: 30)],
          lastWakeAt: at(10),
          now: at(10, 5),
        ),
      );
      // 150 * 0.825 = 124 min ≈ 12:04.
      expect(p.shortNapAdjusted, isTrue);
      expect(p.wakeWindowMinutes, 124);
      expect(p.explanation, contains('short'));
    });

    test('personal drift shifts the window and is clamped to ±20', () {
      final base = engine.predict(ctx(now: at(8)));
      final drifted = engine.predict(ctx(now: at(8), drift: 45));
      expect(drifted.windowStart.difference(base.windowStart).inMinutes, 20);
    });
  });

  group('predict — bedtime', () {
    test('after all naps, next up is bedtime', () {
      final naps = [
        CompletedNap(endedAt: at(9, 30), minutes: 60),
        CompletedNap(endedAt: at(12, 30), minutes: 60),
        CompletedNap(endedAt: at(16, 0), minutes: 60),
      ];
      final p = engine.predict(
        ctx(naps: naps, lastWakeAt: at(16), now: at(16, 10)),
      );
      expect(p.kind, NextUpKind.bedtime);
      // 16:00 + 180 min = 19:00 = target bedtime → no compression.
      expect(p.bedtimeCompressed, isFalse);
      expect(p.windowStart, at(18, 45));
      expect(p.windowEnd, at(19, 15));
    });

    test('late drift is compressed toward target bedtime', () {
      final naps = [
        CompletedNap(endedAt: at(10), minutes: 60),
        CompletedNap(endedAt: at(14), minutes: 60),
        CompletedNap(endedAt: at(17, 30), minutes: 60),
      ];
      final p = engine.predict(
        ctx(naps: naps, lastWakeAt: at(17, 30), now: at(17, 40)),
      );
      // Naive 17:30 + 180 = 20:30, capped to 19:30 (target + 30).
      expect(p.kind, NextUpKind.bedtime);
      expect(p.bedtimeCompressed, isTrue);
      expect(p.windowEnd, at(19, 45));
    });

    test('very early projection is floored an hour before target', () {
      final naps = [
        CompletedNap(endedAt: at(9), minutes: 30),
        CompletedNap(endedAt: at(11), minutes: 30),
        CompletedNap(endedAt: at(13), minutes: 30),
      ];
      final p = engine.predict(
        ctx(naps: naps, lastWakeAt: at(13), now: at(13, 10)),
      );
      // Naive 13:00 + ~148 min ≈ 15:28, floored to 18:00 (target − 60).
      expect(p.kind, NextUpKind.bedtime);
      expect(p.bedtimeCompressed, isTrue);
      expect(p.windowStart, at(17, 45));
    });
  });

  group('transition detection', () {
    test('flags when 4 of last 7 days disagree with the table', () {
      // 30 weeks expects 3 naps; five 2-nap days disagree.
      final t = engine.detectTransition(30, [2, 3, 2, 2, 3, 2, 2]);
      expect(t, isNotNull);
      expect(t!.tableNaps, 3);
      expect(t.observedNaps, 2);
      expect(t.dropping, isTrue);
    });

    test('does not flag with only 3 disagreeing days', () {
      expect(engine.detectTransition(30, [2, 3, 2, 3, 3, 2, 3]), isNull);
    });

    test('does not flag with sparse history', () {
      expect(engine.detectTransition(30, [2, 2, 2]), isNull);
    });

    test('respects a parent-confirmed override', () {
      expect(
        engine.detectTransition(30, [2, 2, 2, 2, 2, 2, 2], napsOverride: 2),
        isNull,
      );
    });

    test('only considers the last 7 days', () {
      // Old disagreement, recent agreement.
      final counts = [2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3];
      expect(engine.detectTransition(30, counts), isNull);
    });
  });

  group('schedule override', () {
    test('override changes when bedtime arrives', () {
      final naps = [
        CompletedNap(endedAt: at(10), minutes: 60),
        CompletedNap(endedAt: at(14), minutes: 60),
      ];
      final withoutOverride = engine.predict(
        ctx(naps: naps, lastWakeAt: at(14), now: at(14, 10)),
      );
      final withOverride = engine.predict(
        ctx(naps: naps, lastWakeAt: at(14), now: at(14, 10), override: 2),
      );
      expect(withoutOverride.kind, NextUpKind.nap);
      expect(withOverride.kind, NextUpKind.bedtime);
    });
  });
}
