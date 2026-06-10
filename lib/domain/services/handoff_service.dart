import 'package:equatable/equatable.dart';

import '../engine/sleep_prediction_engine.dart';
import '../models/care_event.dart';

class HandoffSummary extends Equatable {
  const HandoffSummary({
    required this.headline,
    required this.statusLine,
    required this.lines,
    required this.headsUp,
    required this.shareText,
  });

  /// e.g. "Handoff for Mae · 3:40 pm"
  final String headline;

  /// Current sleep state in one sentence.
  final String statusLine;

  /// Day recap bullets, in priority order.
  final List<String> lines;

  /// What the next caregiver should know (guidance + last note).
  final List<String> headsUp;

  /// Full plain-text version for copy/share to non-app caregivers.
  final String shareText;

  @override
  List<Object?> get props => [headline, statusLine, lines, headsUp, shareText];
}

/// Builds the plain-language caregiver handoff. Pure Dart and deterministic —
/// the same day always produces the same words.
class HandoffService {
  const HandoffService();

  HandoffSummary build({
    required String babyName,
    required DateTime now,
    required List<CareEvent> todayEvents,
    required Map<String, String> caregiverNames,
    NextUpPrediction? prediction,
  }) {
    final sorted = [...todayEvents]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final sleeps = sorted.where((e) => e.isSleep).toList();
    final ongoing = sleeps.where((e) => e.isOngoingSleep).toList();
    final completedNaps = sleeps.where((e) => e.endAt != null).toList();
    final feeds = sorted.where((e) => e.type == CareEventType.feed).toList();
    final diapers = sorted
        .where((e) => e.type == CareEventType.diaper)
        .toList();
    final notes = sorted
        .where((e) => (e.note ?? '').trim().isNotEmpty)
        .toList();
    final nightWakings = sorted
        .where((e) => e.type == CareEventType.nightWaking)
        .toList();

    // Status line.
    String statusLine;
    if (ongoing.isNotEmpty) {
      final sleep = ongoing.last;
      final mins = now.difference(sleep.startAt).inMinutes;
      statusLine =
          '$babyName is asleep — went down at ${_time(sleep.startAt)} (${_dur(mins)} so far).';
    } else if (completedNaps.isNotEmpty) {
      final last = completedNaps.last;
      final napMins = last.duration!.inMinutes;
      statusLine = napMins < 1
          ? '$babyName woke at ${_time(last.endAt!)} from a very short nap.'
          : '$babyName woke at ${_time(last.endAt!)} from a ${_dur(napMins)} nap.';
    } else {
      statusLine =
          '$babyName has been awake since this morning — no sleep logged yet.';
    }

    final lines = <String>[];

    // Day sleep recap.
    if (completedNaps.isNotEmpty) {
      final total = completedNaps.fold<int>(
        0,
        (sum, e) => sum + e.duration!.inMinutes,
      );
      final napWord = completedNaps.length == 1 ? 'nap' : 'naps';
      lines.add(
        '${completedNaps.length} $napWord so far today, ${_dur(total)} of day sleep.',
      );
    } else {
      lines.add('No naps logged yet today.');
    }

    // Next window.
    if (prediction != null) {
      final windowText =
          '${_time(prediction.windowStart)}–${_time(prediction.windowEnd)}';
      if (prediction.kind == NextUpKind.bedtime) {
        lines.add('Aim for bedtime around $windowText.');
      } else {
        lines.add('Next nap window opens around $windowText.');
      }
    }

    // Feeds.
    if (feeds.isNotEmpty) {
      final last = feeds.last;
      lines.add(
        'Last feed: ${_feedKind(last.feedKind)} at ${_time(last.startAt)}'
        '${feeds.length > 1 ? ' (${feeds.length} feeds today)' : ''}.',
      );
    }

    // Diapers.
    if (diapers.isNotEmpty) {
      final last = diapers.last;
      lines.add(
        'Last diaper: ${_diaperKind(last.diaperKind)} at ${_time(last.startAt)}.',
      );
    }

    // Night wakings.
    if (nightWakings.isNotEmpty) {
      final word = nightWakings.length == 1 ? 'night waking' : 'night wakings';
      lines.add('${nightWakings.length} $word logged.');
    }

    // Heads up section.
    final headsUp = <String>[];
    if (notes.isNotEmpty) {
      final last = notes.last;
      final author = caregiverNames[last.loggedById] ?? 'a caregiver';
      headsUp.add('Last note from $author: "${last.note!.trim()}"');
    }
    if (prediction != null) {
      headsUp.add(prediction.explanation);
      if (prediction.transition != null) {
        final t = prediction.transition!;
        headsUp.add(
          t.dropping
              ? 'Recent days look like ${t.observedNaps}-nap days — a nap transition may be underway.'
              : 'Recent days show more naps than usual for this age.',
        );
      }
    }
    if (headsUp.isEmpty) {
      headsUp.add('Nothing unusual flagged today.');
    }

    final headline = 'Handoff for $babyName · ${_time(now)}';

    final buffer = StringBuffer()
      ..writeln(headline)
      ..writeln()
      ..writeln(statusLine);
    for (final l in lines) {
      buffer.writeln(l);
    }
    buffer
      ..writeln()
      ..writeln('For the next caregiver:');
    for (final l in headsUp) {
      buffer.writeln('- $l');
    }
    buffer
      ..writeln()
      ..writeln('Sent with BabyRelay');

    return HandoffSummary(
      headline: headline,
      statusLine: statusLine,
      lines: lines,
      headsUp: headsUp,
      shareText: buffer.toString().trimRight(),
    );
  }

  String _time(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour < 12 ? 'am' : 'pm';
    return '$hour12:$minute $suffix';
  }

  String _dur(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return h == 1 ? '1 hour' : '$h hours';
    return '${h}h ${m}m';
  }

  String _feedKind(FeedKind? kind) {
    switch (kind) {
      case FeedKind.bottle:
        return 'bottle';
      case FeedKind.nursing:
        return 'nursing';
      case FeedKind.solids:
        return 'solids';
      case null:
        return 'feed';
    }
  }

  String _diaperKind(DiaperKind? kind) {
    switch (kind) {
      case DiaperKind.wet:
        return 'wet';
      case DiaperKind.dirty:
        return 'dirty';
      case DiaperKind.both:
        return 'wet + dirty';
      case null:
        return 'change';
    }
  }
}
