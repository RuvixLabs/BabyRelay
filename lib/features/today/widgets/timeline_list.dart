import 'package:flutter/material.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';
import '../../../core/util/formats.dart';
import '../../../domain/models/care_event.dart';
import '../../../domain/models/caregiver.dart';

/// The shared day, drawn as a time rail: time on the left, a colored marker
/// on a continuous line, the event and its author on the right.
class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.events,
    required this.caregivers,
    required this.now,
    this.childName,
    this.onTapEvent,
  });

  /// Newest first.
  final List<CareEvent> events;
  final List<Caregiver> caregivers;
  final DateTime now;
  final String? childName;
  final ValueChanged<CareEvent>? onTapEvent;

  Caregiver? _caregiverFor(String id) {
    for (final c in caregivers) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    if (events.isEmpty) {
      return RelayCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: c.nightGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nightlight_round, color: c.onNight, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Nothing logged yet today', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tap the big button when ${childName ?? 'baby'} falls asleep — that\'s the whole job.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RelayCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineRow(
              event: events[i],
              caregiver: _caregiverFor(events[i].loggedById),
              now: now,
              isFirst: i == 0,
              isLast: i == events.length - 1,
              onTap: onTapEvent == null ? null : () => onTapEvent!(events[i]),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.caregiver,
    required this.now,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final CareEvent event;
  final Caregiver? caregiver;
  final DateTime now;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  (IconData, Color, String, String?) _describe(BuildContext context) {
    final c = context.relay;
    switch (event.type) {
      case CareEventType.sleep:
        if (event.isOngoingSleep) {
          final mins = now.difference(event.startAt).inMinutes;
          return (
            Icons.nightlight_round,
            c.dusk,
            mins < 1
                ? 'Sleeping · just now'
                : 'Sleeping · ${formatDurationMinutes(mins)} so far',
            null,
          );
        }
        final mins = event.duration!.inMinutes;
        return (
          Icons.nightlight_round,
          c.dusk,
          '${event.merged ? 'Sleep (merged)' : 'Sleep'} · ${mins < 1 ? 'under a minute' : formatDurationMinutes(mins)}',
          'until ${formatTime(event.endAt!)}',
        );
      case CareEventType.feed:
        final kind = switch (event.feedKind) {
          FeedKind.bottle => 'Bottle',
          FeedKind.nursing => 'Nursing',
          FeedKind.solids => 'Solids',
          null => 'Feed',
        };
        return (Icons.local_drink_outlined, c.clay, kind, null);
      case CareEventType.diaper:
        final kind = switch (event.diaperKind) {
          DiaperKind.wet => 'Wet diaper',
          DiaperKind.dirty => 'Dirty diaper',
          DiaperKind.both => 'Wet + dirty diaper',
          null => 'Diaper',
        };
        return (Icons.baby_changing_station, c.sage, kind, null);
      case CareEventType.note:
        return (Icons.sticky_note_2_outlined, c.sun, 'Note', null);
      case CareEventType.nightWaking:
        return (Icons.dark_mode_outlined, c.dusk, 'Night waking', null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final (icon, color, title, subtitle) = _describe(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time column — tabular figures keep it a clean rail.
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: Text(
                    formatTime(event.startAt),
                    style: text.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              // Rail with event marker.
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 10,
                      color: isFirst ? Colors.transparent : c.outline,
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast ? Colors.transparent : c.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(fontSize: 13.5),
                        ),
                      if ((event.note ?? '').trim().isNotEmpty &&
                          event.type != CareEventType.note)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            event.note!.trim(),
                            style: text.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              fontSize: 13.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (event.type == CareEventType.note)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            event.note?.trim() ?? '',
                            style: text.bodyLarge?.copyWith(fontSize: 15),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (caregiver != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Tooltip(
                    message: 'Logged by ${caregiver!.name}',
                    child: CaregiverDot(caregiver: caregiver!, size: 26),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: c.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
