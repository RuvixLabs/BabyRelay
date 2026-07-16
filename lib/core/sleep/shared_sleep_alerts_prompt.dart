import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sleep_runtime_service.dart';

/// Explains the cross-caregiver value before triggering the platform prompt.
/// Call this after a caregiver joins, while the user still understands why
/// BabyRelay needs notification permission.
Future<bool> offerSharedSleepAlerts(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text('See shared sleep updates'),
      content: const Text(
        'Allow alerts so a sleep started by another caregiver can appear on '
        'your Lock Screen. On supported iPhones, BabyRelay also uses Live '
        'Activities and Dynamic Island.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Allow alerts'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return false;
  return context.read<SleepRuntimeService>().requestSharedSleepAlerts();
}
