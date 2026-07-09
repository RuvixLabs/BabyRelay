import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../app/app_chrome.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/util/formats.dart';
import '../../data/family_repository.dart';
import '../../domain/models/care_event.dart';

/// Fast, forgiving editing: adjust times, tweak the note, merge overlapping
/// sleeps, or delete — all from one sheet.
Future<void> showEventEditSheet(BuildContext context, CareEvent event) {
  final repo = context.read<FamilyRepository>();
  final analytics = context.read<AnalyticsService>();
  return showRelayModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _EventEditSheet(event: event, repo: repo, analytics: analytics),
  );
}

class _EventEditSheet extends StatefulWidget {
  const _EventEditSheet({
    required this.event,
    required this.repo,
    required this.analytics,
  });

  final CareEvent event;
  final FamilyRepository repo;
  final AnalyticsService analytics;

  @override
  State<_EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<_EventEditSheet> {
  late DateTime _startAt = widget.event.startAt;
  late DateTime? _endAt = widget.event.endAt;
  late final TextEditingController _noteController = TextEditingController(
    text: widget.event.note ?? '',
  );

  String get _title {
    switch (widget.event.type) {
      case CareEventType.sleep:
        return 'Edit sleep';
      case CareEventType.feed:
        return 'Edit feed';
      case CareEventType.diaper:
        return 'Edit diaper';
      case CareEventType.note:
        return 'Edit note';
      case CareEventType.nightWaking:
        return 'Edit night waking';
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return null;
    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      initial.hour,
      initial.minute,
    );
  }

  Future<DateTime?> _pickTime(DateTime initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) return null;
    return DateTime(
      initial.year,
      initial.month,
      initial.day,
      picked.hour,
      picked.minute,
    );
  }

  Future<void> _save() async {
    var endAt = _endAt;
    if (endAt != null && endAt.isBefore(_startAt)) {
      endAt = _startAt;
    }
    final note = _noteController.text.trim();
    await widget.repo.updateEvent(
      widget.event.copyWith(
        startAt: _startAt,
        endAt: endAt,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
      ),
    );
    widget.analytics.logEvent('care_event_edited', {
      'type': widget.event.type.name,
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'This removes it from the shared timeline for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repo.deleteEvent(widget.event.id);
    widget.analytics.logEvent('care_event_deleted', {
      'type': widget.event.type.name,
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _merge(CareEvent other) async {
    await widget.repo.mergeSleepEvents(widget.event, other);
    widget.analytics.logEvent('care_events_merged');
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep entries merged into one')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final overlaps = widget.repo.overlappingSleeps(widget.event);
    final editors = widget.event.editedByIds
        .map((id) {
          for (final caregiver in widget.repo.state.caregivers) {
            if (caregiver.id == id) return caregiver.name;
          }
          return null;
        })
        .whereType<String>()
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_title, style: text.titleLarge)),
                  IconButton(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: c.danger),
                    tooltip: 'Delete entry',
                  ),
                ],
              ),
              if (overlaps.isNotEmpty) ...[
                const SizedBox(height: 8),
                RelayCard(
                  color: c.sun.withValues(alpha: 0.10),
                  borderColor: c.sun.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overlapping sleep entries',
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Two caregivers may have logged the same sleep. You can merge them into one entry.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final other in overlaps)
                        TextButton.icon(
                          onPressed: () => _merge(other),
                          icon: const Icon(Icons.merge_type, size: 18),
                          label: Text(
                            'Merge with ${formatTime(other.startAt)}'
                            '${other.endAt != null ? ' – ${formatTime(other.endAt!)}' : ' (ongoing)'}',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _DateTimeRow(
                label: widget.event.isSleep ? 'Fell asleep' : 'Time',
                value: _startAt,
                onDateTap: () async {
                  final picked = await _pickDate(_startAt);
                  if (picked != null) setState(() => _startAt = picked);
                },
                onTimeTap: () async {
                  final picked = await _pickTime(_startAt);
                  if (picked != null) setState(() => _startAt = picked);
                },
              ),
              if (widget.event.isSleep && _endAt != null) ...[
                const SizedBox(height: 10),
                _DateTimeRow(
                  label: 'Woke up',
                  value: _endAt!,
                  onDateTap: () async {
                    final picked = await _pickDate(_endAt!);
                    if (picked != null) setState(() => _endAt = picked);
                  },
                  onTimeTap: () async {
                    final picked = await _pickTime(_endAt!);
                    if (picked != null) setState(() => _endAt = picked);
                  },
                ),
              ],
              if (widget.event.isSleep && _endAt == null) ...[
                const SizedBox(height: 10),
                Text(
                  'Still sleeping — end the sleep from Today.',
                  style: text.bodyMedium,
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Anything the next caregiver should know',
                ),
              ),
              if (editors.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Edited by ${editors.join(', ')}', style: text.bodyMedium),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: _save, child: const Text('Save changes')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onDateTap,
    required this.onTimeTap,
  });

  static final _date = DateFormat('EEE d MMM');

  final String label;
  final DateTime value;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          TextButton(onPressed: onDateTap, child: Text(_date.format(value))),
          const SizedBox(width: 2),
          TextButton(
            onPressed: onTimeTap,
            child: Text(
              formatTime(value),
              style: text.titleMedium?.copyWith(color: c.clayDeep),
            ),
          ),
          Icon(Icons.edit_outlined, size: 16, color: c.inkFaint),
        ],
      ),
    );
  }
}
