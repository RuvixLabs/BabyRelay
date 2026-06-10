import 'package:flutter/material.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';
import '../../../core/util/formats.dart';
import '../../../domain/engine/sleep_prediction_engine.dart';
import '../../../domain/models/care_event.dart';

/// The hero card: what's next, in plain language, with the "why" one line
/// below. While the baby sleeps it becomes a calm dusk-toned sleep card.
class NextUpCard extends StatelessWidget {
  const NextUpCard({
    super.key,
    required this.now,
    this.prediction,
    this.ongoingSleep,
    this.predictionIfWakesNow,
    this.onTransitionAccept,
    this.onTransitionDismiss,
  });

  final DateTime now;
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
      final mins = now.difference(ongoingSleep!.startAt).inMinutes;
      return RelayCard(
        color: c.duskSoft,
        borderColor: c.dusk.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round, size: 18, color: c.dusk),
                const SizedBox(width: 8),
                Text('ASLEEP', style: text.labelSmall?.copyWith(color: c.dusk)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mins < 1
                  ? 'Just fell asleep'
                  : 'Sleeping for ${formatDurationMinutes(mins)}',
              style: text.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Went down at ${formatTime(ongoingSleep!.startAt)}.'
              '${predictionIfWakesNow != null ? ' If they wake now, the next window opens around ${formatTime(predictionIfWakesNow!.windowStart)}.' : ''}',
              style: text.bodyMedium,
            ),
          ],
        ),
      );
    }

    final p = prediction;
    if (p == null) {
      return RelayCard(
        child: Text(
          'Log a nap to start next-up guidance.',
          style: text.bodyMedium,
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
        RelayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBedtime ? Icons.bedtime_outlined : Icons.wb_twilight,
                    size: 18,
                    color: c.clayDeep,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NEXT UP · $title'.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: c.clayDeep),
                  ),
                  const Spacer(),
                  if (overdue)
                    RelayChip('Window passed', color: c.sun)
                  else
                    RelayChip(relative, color: c.sage),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                windowLabel,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                p.explanation,
                style: Theme.of(context).textTheme.bodyMedium,
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
