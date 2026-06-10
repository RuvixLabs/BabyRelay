import 'package:flutter/material.dart';

import '../../../core/design/relay_theme.dart';
import '../../../domain/models/care_event.dart';

Future<FeedKind?> showFeedSheet(BuildContext context) {
  return _showPicker<FeedKind>(
    context,
    title: 'Log a feed',
    options: const [
      (FeedKind.bottle, Icons.local_drink_outlined, 'Bottle'),
      (FeedKind.nursing, Icons.favorite_outline, 'Nursing'),
      (FeedKind.solids, Icons.restaurant_outlined, 'Solids'),
    ],
  );
}

Future<DiaperKind?> showDiaperSheet(BuildContext context) {
  return _showPicker<DiaperKind>(
    context,
    title: 'Log a diaper',
    options: const [
      (DiaperKind.wet, Icons.water_drop_outlined, 'Wet'),
      (DiaperKind.dirty, Icons.cloud_outlined, 'Dirty'),
      (DiaperKind.both, Icons.all_inclusive, 'Both'),
    ],
  );
}

Future<T?> _showPicker<T>(
  BuildContext context, {
  required String title,
  required List<(T, IconData, String)> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.relay;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (value, icon, label) in options) ...[
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(value),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: c.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.outline),
                          ),
                          child: Column(
                            children: [
                              Icon(icon, size: 28, color: c.clay),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (options.last.$1 != value) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showNoteSheet(BuildContext context) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a note',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Notes travel with the handoff so the next caregiver sees them.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Finished bottle before nap, a bit fussy',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    final note = controller.text.trim();
                    Navigator.of(sheetContext).pop(note.isEmpty ? null : note);
                  },
                  child: const Text('Save note'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
