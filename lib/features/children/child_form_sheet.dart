import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_chrome.dart';
import '../../core/design/relay_theme.dart';
import '../../domain/models/baby_profile.dart';

/// Bottom-sheet form for adding or editing a child. Returns the draft
/// profile (id empty when adding — the repository assigns one).
Future<BabyProfile?> showChildFormSheet(
  BuildContext context, {
  BabyProfile? existing,
}) {
  return showRelayModalBottomSheet<BabyProfile>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ChildFormSheet(existing: existing),
  );
}

class _ChildFormSheet extends StatefulWidget {
  const _ChildFormSheet({this.existing});

  final BabyProfile? existing;

  @override
  State<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends State<_ChildFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.nickname ?? '',
  );
  late DateTime _dob =
      widget.existing?.dob ??
      DateTime.now().subtract(const Duration(days: 150));
  late int _wakeMinutes = widget.existing?.wakeTimeMinutes ?? 7 * 60;
  late int _bedMinutes = widget.existing?.bedtimeMinutes ?? 19 * 60;
  late int _naps = widget.existing?.napsPerDayEstimate ?? 3;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _timeLabel(int minutes) {
    final h12 = (minutes ~/ 60) % 12 == 0 ? 12 : (minutes ~/ 60) % 12;
    final suffix = minutes < 720 ? 'am' : 'pm';
    return '$h12:${(minutes % 60).toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickTime(
    int current,
    String help,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: help,
    );
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    final profile = existing == null
        ? BabyProfile(
            id: '',
            nickname: name,
            dob: _dob,
            wakeTimeMinutes: _wakeMinutes,
            bedtimeMinutes: _bedMinutes,
            napsPerDayEstimate: _naps,
          )
        : existing.copyWith(
            nickname: name,
            dob: _dob,
            wakeTimeMinutes: _wakeMinutes,
            bedtimeMinutes: _bedMinutes,
            napsPerDayEstimate: _naps,
          );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final adding = widget.existing == null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adding ? 'Add a child' : 'Edit ${widget.existing!.nickname}',
                style: text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                adding
                    ? 'Same care team, their own timeline and guidance.'
                    : 'Profile and typical day — guidance adapts from here.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: adding,
                textCapitalization: TextCapitalization.words,
                style: text.titleMedium,
                decoration: const InputDecoration(
                  labelText: 'Name or nickname',
                  hintText: 'e.g. Mae, Bubba, Little O',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _FormRow(
                icon: Icons.cake_outlined,
                label: 'Born',
                value: DateFormat('MMM d, y').format(_dob),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365 * 6),
                    ),
                    lastDate: DateTime.now(),
                    helpText: 'Date of birth',
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
              const SizedBox(height: 10),
              _FormRow(
                icon: Icons.wb_sunny_outlined,
                label: 'Usually wakes',
                value: _timeLabel(_wakeMinutes),
                onTap: () => _pickTime(
                  _wakeMinutes,
                  'Typical wake time',
                  (v) => setState(() => _wakeMinutes = v),
                ),
              ),
              const SizedBox(height: 10),
              _FormRow(
                icon: Icons.bedtime_outlined,
                label: 'Bedtime around',
                value: _timeLabel(_bedMinutes),
                onTap: () => _pickTime(
                  _bedMinutes,
                  'Target bedtime',
                  (v) => setState(() => _bedMinutes = v),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Naps per day right now',
                      style: text.bodyLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _naps > 0
                        ? () => setState(() => _naps -= 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_naps', style: text.titleLarge),
                  IconButton(
                    onPressed: _naps < 6
                        ? () => setState(() => _naps += 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _name.text.trim().isEmpty ? null : _save,
                child: Text(adding ? 'Add child' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.relay.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.clayDeep, size: 21),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: text.bodyLarge)),
            Text(value, style: text.titleMedium?.copyWith(color: c.clayDeep)),
          ],
        ),
      ),
    );
  }
}
