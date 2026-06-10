import 'package:flutter/material.dart';

import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';
import '../../../core/util/formats.dart';
import '../../../domain/models/care_event.dart';
import '../../../domain/models/caregiver.dart';

class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.events,
    required this.caregivers,
    required this.now,
    this.onTapEvent,
  });

  /// Newest first.
  final List<CareEvent> events;
  final List<Caregiver> caregivers;
  final DateTime now;
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
            Icon(Icons.auto_awesome, color: c.inkFaint, size: 32),
            const SizedBox(height: 10),
            Text('Nothing logged yet today', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tap the big button when baby falls asleep — that\'s the whole job.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RelayCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 64, color: c.outline),
            _TimelineRow(
              event: events[i],
              caregiver: _caregiverFor(events[i].loggedById),
              now: now,
              onTap: onTapEvent == null ? null : () => onTapEvent!(events[i]),
            ),
          ],
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
    this.onTap,
  });

  final CareEvent event;
  final Caregiver? caregiver;
  final DateTime now;
  final VoidCallback? onTap;

  (IconData, Color, String, String) _describe(BuildContext context) {
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
            'since ${formatTime(event.startAt)}',
          );
        }
        final mins = event.duration!.inMinutes;
        return (
          Icons.nightlight_round,
          c.dusk,
          '${event.merged ? 'Sleep (merged)' : 'Sleep'} · ${mins < 1 ? 'under a minute' : formatDurationMinutes(mins)}',
          '${formatTime(event.startAt)} – ${formatTime(event.endAt!)}',
        );
      case CareEventType.feed:
        final kind = switch (event.feedKind) {
          FeedKind.bottle => 'Bottle',
          FeedKind.nursing => 'Nursing',
          FeedKind.solids => 'Solids',
          null => 'Feed',
        };
        return (
          Icons.local_drink_outlined,
          c.clay,
          kind,
          formatTime(event.startAt),
        );
      case CareEventType.diaper:
        final kind = switch (event.diaperKind) {
          DiaperKind.wet => 'Wet diaper',
          DiaperKind.dirty => 'Dirty diaper',
          DiaperKind.both => 'Wet + dirty diaper',
          null => 'Diaper',
        };
        return (
          Icons.baby_changing_station,
          c.sage,
          kind,
          formatTime(event.startAt),
        );
      case CareEventType.note:
        return (
          Icons.sticky_note_2_outlined,
          c.sun,
          'Note',
          formatTime(event.startAt),
        );
      case CareEventType.nightWaking:
        return (
          Icons.dark_mode_outlined,
          c.dusk,
          'Night waking',
          formatTime(event.startAt),
        );
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  Text(subtitle, style: text.bodyMedium),
                  if ((event.note ?? '').trim().isNotEmpty &&
                      event.type != CareEventType.note)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        event.note!.trim(),
                        style: text.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
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
                        style: text.bodyLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (caregiver != null)
              Tooltip(
                message: 'Logged by ${caregiver!.name}',
                child: CaregiverDot(caregiver: caregiver!, size: 26),
              )
            else
              Icon(Icons.person_outline, size: 18, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}
