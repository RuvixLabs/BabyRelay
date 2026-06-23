import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_chrome.dart';
import '../../../core/design/relay_theme.dart';
import '../../../core/design/relay_widgets.dart';
import '../../../core/util/formats.dart';

class ManualSleepDraft {
  const ManualSleepDraft({
    required this.startAt,
    required this.endAt,
    this.note,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String? note;
}

Future<ManualSleepDraft?> showManualSleepSheet(
  BuildContext context, {
  required DateTime now,
  String? childName,
}) {
  return showRelayModalBottomSheet<ManualSleepDraft>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _ManualSleepSheet(now: now, childName: childName),
  );
}

class _ManualSleepSheet extends StatefulWidget {
  const _ManualSleepSheet({required this.now, this.childName});

  final DateTime now;
  final String? childName;

  @override
  State<_ManualSleepSheet> createState() => _ManualSleepSheetState();
}

class _ManualSleepSheetState extends State<_ManualSleepSheet> {
  late DateTime _startAt = widget.now.subtract(const Duration(minutes: 70));
  late DateTime _endAt = widget.now.subtract(const Duration(minutes: 10));
  late final TextEditingController _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _applyPreset(Duration duration, {DateTime? endingAt}) {
    final end = endingAt ?? widget.now;
    setState(() {
      _endAt = end;
      _startAt = end.subtract(duration);
      _error = null;
    });
  }

  void _applyOvernightPreset() {
    final end = DateTime(widget.now.year, widget.now.month, widget.now.day, 7);
    setState(() {
      _endAt = end.isAfter(widget.now) ? widget.now : end;
      _startAt = _endAt.subtract(const Duration(hours: 11));
      _error = null;
    });
  }

  Future<void> _pickDate({
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: widget.now.subtract(const Duration(days: 30)),
      lastDate: widget.now,
    );
    if (picked == null) return;
    onChanged(
      DateTime(picked.year, picked.month, picked.day, value.hour, value.minute),
    );
  }

  Future<void> _pickTime({
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (picked == null) return;
    onChanged(
      DateTime(value.year, value.month, value.day, picked.hour, picked.minute),
    );
  }

  void _save() {
    final duration = _endAt.difference(_startAt);
    if (duration.inMicroseconds <= 0) {
      setState(() => _error = 'Wake time must be after sleep time.');
      return;
    }
    if (duration.inMinutes < 5) {
      setState(() => _error = 'Sleep entries need to be at least 5 minutes.');
      return;
    }
    if (duration.inHours >= 24) {
      setState(() => _error = 'Split anything over 24 hours into two entries.');
      return;
    }
    if (_startAt.isAfter(widget.now) || _endAt.isAfter(widget.now)) {
      setState(() => _error = 'Past sleep entries cannot be in the future.');
      return;
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      ManualSleepDraft(
        startAt: _startAt,
        endAt: _endAt,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final durationMinutes = _endAt.difference(_startAt).inMinutes;
    final durationLabel = durationMinutes <= 0
        ? 'Check times'
        : formatDurationMinutes(durationMinutes);

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
                  IconSquare(icon: Icons.history_rounded, color: c.dusk),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add past sleep', style: text.titleLarge),
                        Text(
                          'For the nap someone forgot to start.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Last 45 min',
                    onTap: () => _applyPreset(const Duration(minutes: 45)),
                  ),
                  _PresetChip(
                    label: '1h nap',
                    onTap: () => _applyPreset(const Duration(hours: 1)),
                  ),
                  _PresetChip(
                    label: '2h nap',
                    onTap: () => _applyPreset(const Duration(hours: 2)),
                  ),
                  _PresetChip(label: 'Overnight', onTap: _applyOvernightPreset),
                ],
              ),
              const SizedBox(height: 16),
              RelayCard(
                padding: const EdgeInsets.all(16),
                color: c.nightHigh.withValues(alpha: 0.08),
                borderColor: c.nightHigh.withValues(alpha: 0.18),
                child: Column(
                  children: [
                    _DateTimeRow(
                      label: 'Fell asleep',
                      value: _startAt,
                      onDateTap: () => _pickDate(
                        value: _startAt,
                        onChanged: (value) => setState(() {
                          _startAt = value;
                          _error = null;
                        }),
                      ),
                      onTimeTap: () => _pickTime(
                        value: _startAt,
                        onChanged: (value) => setState(() {
                          _startAt = value;
                          _error = null;
                        }),
                      ),
                    ),
                    const Divider(height: 18),
                    _DateTimeRow(
                      label: 'Woke up',
                      value: _endAt,
                      onDateTap: () => _pickDate(
                        value: _endAt,
                        onChanged: (value) => setState(() {
                          _endAt = value;
                          _error = null;
                        }),
                      ),
                      onTimeTap: () => _pickTime(
                        value: _endAt,
                        onChanged: (value) => setState(() {
                          _endAt = value;
                          _error = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RelayCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                color: c.surface,
                borderColor: c.outline,
                child: Row(
                  children: [
                    Icon(Icons.nightlight_round, color: c.dusk, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.childName ?? 'Baby'} slept $durationLabel',
                        style: text.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Woke happy, needed rocking first',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Add sleep'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      avatar: Icon(Icons.replay_rounded, size: 18, color: c.dusk),
      backgroundColor: c.surface,
      side: BorderSide(color: c.outline),
      labelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
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
    return Row(
      children: [
        Expanded(child: Text(label, style: text.bodyLarge)),
        TextButton(onPressed: onDateTap, child: Text(_date.format(value))),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onTimeTap,
          child: Text(
            formatTime(value),
            style: TextStyle(color: c.clayDeep, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
