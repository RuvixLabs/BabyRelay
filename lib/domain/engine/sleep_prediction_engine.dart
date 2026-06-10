import 'package:equatable/equatable.dart';

/// Age-band wake window rules. All durations are minutes.
///
/// Bands come from docs/plans/core/overview.md and are deliberately
/// deterministic and explainable — no ML, no opaque scores.
class AgeBand {
  const AgeBand({
    required this.minWeeks,
    required this.maxWeeks,
    required this.minNaps,
    required this.maxNaps,
    required this.minWakeWindow,
    required this.maxWakeWindow,
    required this.label,
  });

  final int minWeeks;
  final int maxWeeks; // exclusive
  final int minNaps;
  final int maxNaps;
  final int minWakeWindow;
  final int maxWakeWindow;
  final String label;

  bool contains(int weeks) => weeks >= minWeeks && weeks < maxWeeks;
}

const List<AgeBand> kAgeBands = [
  AgeBand(
    minWeeks: 0,
    maxWeeks: 12,
    minNaps: 4,
    maxNaps: 5,
    minWakeWindow: 45,
    maxWakeWindow: 75,
    label: 'newborn',
  ),
  AgeBand(
    minWeeks: 12,
    maxWeeks: 26,
    minNaps: 3,
    maxNaps: 4,
    minWakeWindow: 105,
    maxWakeWindow: 150,
    label: '3–6 months',
  ),
  AgeBand(
    minWeeks: 26,
    maxWeeks: 39,
    minNaps: 3,
    maxNaps: 3,
    minWakeWindow: 135,
    maxWakeWindow: 180,
    label: '6–9 months',
  ),
  AgeBand(
    minWeeks: 39,
    maxWeeks: 61,
    minNaps: 2,
    maxNaps: 2,
    minWakeWindow: 165,
    maxWakeWindow: 225,
    label: '9–14 months',
  ),
  AgeBand(
    minWeeks: 61,
    maxWeeks: 100000,
    minNaps: 1,
    maxNaps: 2,
    minWakeWindow: 240,
    maxWakeWindow: 360,
    label: '14–24 months',
  ),
];

/// A finished nap earlier today.
class CompletedNap extends Equatable {
  const CompletedNap({required this.endedAt, required this.minutes});

  final DateTime endedAt;
  final int minutes;

  @override
  List<Object?> get props => [endedAt, minutes];
}

/// Everything the engine needs to know about the day so far.
class SleepDayContext extends Equatable {
  const SleepDayContext({
    required this.now,
    required this.ageInWeeks,
    required this.napsToday,
    required this.lastWakeAt,
    required this.wakeTimeMinutes,
    required this.bedtimeMinutes,
    this.personalDriftMinutes = 0,
    this.recentNapCounts = const [],
    this.scheduleOverrideNaps,
  });

  final DateTime now;
  final int ageInWeeks;
  final List<CompletedNap> napsToday;

  /// When the baby last woke up. Null means no sleep logged yet today, so the
  /// morning wake time is used as the anchor.
  final DateTime? lastWakeAt;
  final int wakeTimeMinutes;
  final int bedtimeMinutes;

  /// Personal drift placeholder: observed-vs-predicted offset, clamped ±20.
  final int personalDriftMinutes;

  /// Nap counts for recent full days, newest last. Used for transition
  /// detection.
  final List<int> recentNapCounts;
  final int? scheduleOverrideNaps;

  @override
  List<Object?> get props => [
    now,
    ageInWeeks,
    napsToday,
    lastWakeAt,
    wakeTimeMinutes,
    bedtimeMinutes,
    personalDriftMinutes,
    recentNapCounts,
    scheduleOverrideNaps,
  ];
}

enum NextUpKind { nap, bedtime }

class TransitionSuggestion extends Equatable {
  const TransitionSuggestion({
    required this.tableNaps,
    required this.observedNaps,
  });

  final int tableNaps;
  final int observedNaps;

  bool get dropping => observedNaps < tableNaps;

  @override
  List<Object?> get props => [tableNaps, observedNaps];
}

class NextUpPrediction extends Equatable {
  const NextUpPrediction({
    required this.kind,
    required this.windowStart,
    required this.windowEnd,
    required this.explanation,
    required this.wakeWindowMinutes,
    required this.napsExpected,
    this.shortNapAdjusted = false,
    this.bedtimeCompressed = false,
    this.transition,
  });

  final NextUpKind kind;
  final DateTime windowStart;
  final DateTime windowEnd;

  /// One plain-language sentence explaining where the number came from.
  final String explanation;
  final int wakeWindowMinutes;
  final int napsExpected;
  final bool shortNapAdjusted;
  final bool bedtimeCompressed;
  final TransitionSuggestion? transition;

  @override
  List<Object?> get props => [
    kind,
    windowStart,
    windowEnd,
    explanation,
    wakeWindowMinutes,
    napsExpected,
    shortNapAdjusted,
    bedtimeCompressed,
    transition,
  ];
}

/// Deterministic wake-window engine. Pure Dart, no Flutter imports, fully
/// unit-testable.
class SleepPredictionEngine {
  const SleepPredictionEngine();

  static const int shortNapThresholdMinutes = 45;
  static const double shortNapShrinkFactor = 0.825; // 17.5% shrink
  static const int driftClampMinutes = 20;
  static const int windowHalfWidthMinutes = 15;

  AgeBand bandFor(int ageInWeeks) => kAgeBands.firstWhere(
    (b) => b.contains(ageInWeeks),
    orElse: () => kAgeBands.last,
  );

  /// Expected naps per day for this age, honoring a parent-confirmed override.
  int expectedNaps(int ageInWeeks, {int? override}) {
    if (override != null) return override.clamp(1, 6);
    return bandFor(ageInWeeks).maxNaps;
  }

  /// Wake window before the (napIndex+1)-th sleep of the day. Interpolates
  /// across the band's range: windows get longer as the day goes on.
  int wakeWindowMinutes(int ageInWeeks, int napIndex, {int? napsOverride}) {
    final band = bandFor(ageInWeeks);
    final naps = expectedNaps(ageInWeeks, override: napsOverride);
    // There are `naps + 1` wake windows in a day (last one ends at bedtime).
    final t = naps <= 0 ? 1.0 : (napIndex / naps).clamp(0.0, 1.0);
    final range = band.maxWakeWindow - band.minWakeWindow;
    return (band.minWakeWindow + range * t).round();
  }

  /// Checks whether the observed nap pattern disagrees with the age table on
  /// at least 4 of the last 7 logged days.
  TransitionSuggestion? detectTransition(
    int ageInWeeks,
    List<int> recentNapCounts, {
    int? napsOverride,
  }) {
    if (napsOverride != null) return null; // parent already picked a schedule
    final band = bandFor(ageInWeeks);
    final lastSeven = recentNapCounts.length <= 7
        ? recentNapCounts
        : recentNapCounts.sublist(recentNapCounts.length - 7);
    if (lastSeven.length < 4) return null;
    final disagreeing = lastSeven
        .where((c) => c < band.minNaps || c > band.maxNaps)
        .toList();
    if (disagreeing.length < 4) return null;
    // Suggest the most common observed count among disagreeing days.
    final counts = <int, int>{};
    for (final c in disagreeing) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final observed = counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    return TransitionSuggestion(
      tableNaps: band.maxNaps,
      observedNaps: observed,
    );
  }

  NextUpPrediction predict(SleepDayContext ctx) {
    final napsTaken = ctx.napsToday.length;
    final naps = expectedNaps(
      ctx.ageInWeeks,
      override: ctx.scheduleOverrideNaps,
    );
    final isBedtimeNext = napsTaken >= naps;

    var window = wakeWindowMinutes(
      ctx.ageInWeeks,
      napsTaken,
      napsOverride: ctx.scheduleOverrideNaps,
    );

    // Short-nap adjustment: a nap under 45 minutes shrinks the next window.
    var shortNapAdjusted = false;
    if (ctx.napsToday.isNotEmpty &&
        ctx.napsToday.last.minutes < shortNapThresholdMinutes) {
      window = (window * shortNapShrinkFactor).round();
      shortNapAdjusted = true;
    }

    // Personal drift placeholder, clamped to ±20 minutes.
    final drift = ctx.personalDriftMinutes.clamp(
      -driftClampMinutes,
      driftClampMinutes,
    );
    window += drift;

    final anchor = ctx.lastWakeAt ?? _todayAt(ctx.now, ctx.wakeTimeMinutes);
    var predicted = anchor.add(Duration(minutes: window));

    var bedtimeCompressed = false;
    String explanation;
    final windowLabel = _formatMinutes(window);
    final band = bandFor(ctx.ageInWeeks);

    if (isBedtimeNext) {
      final target = _todayAt(ctx.now, ctx.bedtimeMinutes);
      if (predicted.isAfter(target.add(const Duration(minutes: 30)))) {
        // Hold close to the family's usual bedtime rather than drifting late.
        predicted = target.add(const Duration(minutes: 30));
        bedtimeCompressed = true;
        explanation =
            'Holding close to the usual bedtime even though the last wake window could stretch longer.';
      } else if (predicted.isBefore(
        target.subtract(const Duration(minutes: 60)),
      )) {
        // Don't pull bedtime absurdly early; cap at an hour before target.
        predicted = target.subtract(const Duration(minutes: 60));
        bedtimeCompressed = true;
        explanation = shortNapAdjusted
            ? 'Bedtime moved a little earlier because the last nap was short.'
            : 'Bedtime moved a little earlier to match how the day went.';
      } else {
        explanation =
            'After nap $napsTaken of $naps, a $windowLabel wake window points to bedtime.';
      }
    } else {
      explanation = shortNapAdjusted
          ? 'Wake window trimmed to $windowLabel because the last nap ran short.'
          : 'Typical $windowLabel wake window for a ${band.label} baby before nap ${napsTaken + 1} of $naps.';
    }

    if (drift != 0) {
      explanation += drift > 0
          ? ' Nudged later to match recent days.'
          : ' Nudged earlier to match recent days.';
    }

    final transition = detectTransition(
      ctx.ageInWeeks,
      ctx.recentNapCounts,
      napsOverride: ctx.scheduleOverrideNaps,
    );

    return NextUpPrediction(
      kind: isBedtimeNext ? NextUpKind.bedtime : NextUpKind.nap,
      windowStart: predicted.subtract(
        const Duration(minutes: windowHalfWidthMinutes),
      ),
      windowEnd: predicted.add(const Duration(minutes: windowHalfWidthMinutes)),
      explanation: explanation,
      wakeWindowMinutes: window,
      napsExpected: naps,
      shortNapAdjusted: shortNapAdjusted,
      bedtimeCompressed: bedtimeCompressed,
      transition: transition,
    );
  }

  DateTime _todayAt(DateTime now, int minutesOfDay) => DateTime(
    now.year,
    now.month,
    now.day,
    minutesOfDay ~/ 60,
    minutesOfDay % 60,
  );

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
