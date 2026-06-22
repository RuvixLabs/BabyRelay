import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_chrome.dart';
import '../analytics/analytics_service.dart';
import '../design/relay_theme.dart';
import 'review_prompt_service.dart';

enum _ReviewPromptChoice { positive, needsWork, later }

Future<void> maybeShowTrackingReviewPrompt(BuildContext context) {
  return _maybeShowReviewPrompt(
    context: context,
    moment: ReviewPromptIds.trackingSuccess,
    title: 'Did that log help?',
    body:
        'If BabyRelay made keeping everyone updated feel easier, a quick rating helps other families find it.',
  );
}

Future<void> maybeShowHandoffReviewPrompt(BuildContext context) async {
  return _maybeShowReviewPrompt(
    context: context,
    moment: ReviewPromptIds.handoffSuccess,
    title: 'Did that handoff help?',
    body:
        'If BabyRelay made the next caregiver feel calmer, a quick rating helps other families find it.',
  );
}

Future<void> _maybeShowReviewPrompt({
  required BuildContext context,
  required String moment,
  required String title,
  required String body,
}) async {
  final service = context.read<ReviewPromptService>();
  if (!service.shouldShow(moment)) return;

  final analytics = context.read<AnalyticsService>();
  analytics.logEvent('review_prompt_viewed', {'moment': moment});

  final choice = await showRelayModalBottomSheet<_ReviewPromptChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReviewPromptSheet(title: title, body: body),
  );

  await service.markSeen(moment);

  switch (choice) {
    case _ReviewPromptChoice.positive:
      analytics.logEvent('review_prompt_positive', {'moment': moment});
      await service.requestNativeReview(analytics);
      break;
    case _ReviewPromptChoice.needsWork:
      analytics.logEvent('review_prompt_dismissed', {
        'moment': moment,
        'reason': 'needs_work',
      });
      break;
    case _ReviewPromptChoice.later:
    case null:
      analytics.logEvent('review_prompt_dismissed', {
        'moment': moment,
        'reason': 'later',
      });
      break;
  }
}

class _ReviewPromptSheet extends StatelessWidget {
  const _ReviewPromptSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.sun.withValues(alpha: 0.16),
                  border: Border.all(color: c.sun.withValues(alpha: 0.26)),
                ),
                child: Icon(Icons.favorite_rounded, color: c.clay, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_ReviewPromptChoice.positive),
                icon: const Icon(Icons.star_rounded),
                label: const Text('Yes, it helped'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_ReviewPromptChoice.needsWork),
                child: const Text('Needs work'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_ReviewPromptChoice.later),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
