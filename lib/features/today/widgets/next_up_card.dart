import 'package:flutter/material.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';
import '../../../core/util/formats.dart';
import '../../../domain/engine/sleep_prediction_engine.dart';
import '../../../domain/models/care_event.dart';

/// The hero card: what's next, in plain language, with the "why" one line
/// below. Awake = soft dawn gradient with a low sun; asleep = deep dusk
/// gradient with a starfield, so the emotional register flips with the baby.
class NextUpCard extends StatelessWidget {
  const NextUpCard({
    super.key,
    required this.now,
    this.childName,
    this.prediction,
    this.ongoingSleep,
    this.predictionIfWakesNow,
    this.onTransitionAccept,
    this.onTransitionDismiss,
  });

  final DateTime now;
  final String? childName;
  final NextUpPrediction? prediction;
  final CareEvent? ongoingSleep;
  final NextUpPrediction? predictionIfWakesNow;
  final ValueChanged<int>? onTransitionAccept;
  final VoidCallback? onTransitionDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    if (ongoingSleep != null) {
      final elapsed = now.difference(ongoingSleep!.startAt);
      final timerLabel = formatStopwatch(elapsed);
      final wakePrediction = predictionIfWakesNow == null
          ? null
          : 'If ${childName ?? 'baby'} wakes now, the next window opens around ${formatTime(predictionIfWakesNow!.windowStart)}.';
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Container(
          key: const ValueKey('asleep'),
          decoration: BoxDecoration(
            gradient: c.nightGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: c.nightLow.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: CustomPaint(
                    painter: StarFieldPainter(color: c.onNightSoft),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ASLEEP',
                          style: text.labelSmall?.copyWith(
                            color: c.onNightSoft,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RelayChip('LIVE', color: c.onNight, icon: Icons.circle),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      label: _sleepTimerSemantics(
                        childName: childName,
                        elapsed: elapsed,
                        startedAt: ongoingSleep!.startAt,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          timerLabel,
                          style: text.displaySmall?.copyWith(
                            color: c.onNight,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Down at ${formatTime(ongoingSleep!.startAt)}.'
                      '${wakePrediction == null ? '' : ' $wakePrediction'}',
                      style: text.bodyMedium?.copyWith(color: c.onNightSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final p = prediction;
    if (p == null) {
      return RelayCard(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            IconSquare(icon: Icons.wb_twilight, color: c.sun),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Log a nap to start next-up guidance.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final isBedtime = p.kind == NextUpKind.bedtime;
    final title = isBedtime ? 'Bedtime' : 'Next nap';
    final windowLabel =
        '${formatTime(p.windowStart)} – ${formatTime(p.windowEnd)}';
    final relative = formatRelative(p.windowStart, now);
    final overdue = now.isAfter(p.windowEnd);

    return Column(
      children: [
        Container(
          key: const ValueKey('awake'),
          decoration: BoxDecoration(
            gradient: c.dawnGradient,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: c.sun.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: c.ink.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: CustomPaint(painter: SunArcPainter(color: c.sun)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'NEXT UP · $title'.toUpperCase(),
                          style: text.labelSmall?.copyWith(color: c.clayDeep),
                        ),
                        const Spacer(),
                        if (overdue)
                          RelayChip('Window passed', color: c.clayDeep)
                        else
                          RelayChip(relative, color: c.sage),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(windowLabel, style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      p.explanation,
                      style: text.bodyMedium?.copyWith(
                        color: Color.lerp(c.inkSoft, c.ink, 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p.transition != null) ...[
          const SizedBox(height: 10),
          _TransitionBanner(
            transition: p.transition!,
            onAccept: onTransitionAccept,
            onDismiss: onTransitionDismiss,
          ),
        ],
      ],
    );
  }
}

String _sleepTimerSemantics({
  required String? childName,
  required Duration elapsed,
  required DateTime startedAt,
}) {
  final name = childName ?? 'Baby';
  final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
  final duration = minutes < 1
      ? 'less than 1 minute'
      : formatDurationMinutes(minutes);
  return '$name asleep for $duration, since ${formatTime(startedAt)}.';
}

class _TransitionBanner extends StatelessWidget {
  const _TransitionBanner({
    required this.transition,
    this.onAccept,
    this.onDismiss,
  });

  final TransitionSuggestion transition;
  final ValueChanged<int>? onAccept;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return RelayCard(
      color: c.sun.withValues(alpha: 0.10),
      borderColor: c.sun.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_alt, size: 18, color: c.sun),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Possible nap transition', style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Most recent days look like ${transition.observedNaps}-nap days, '
            'while the age guide expects ${transition.tableNaps}. You know your '
            'baby best — pick what fits.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: () => onAccept?.call(transition.observedNaps),
                child: Text('Switch to ${transition.observedNaps} naps'),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Keep current'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
