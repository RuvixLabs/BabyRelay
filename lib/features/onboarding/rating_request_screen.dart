import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';

class RatingRequestScreen extends StatefulWidget {
  const RatingRequestScreen({super.key});

  @override
  State<RatingRequestScreen> createState() => _RatingRequestScreenState();
}

class _RatingRequestScreenState extends State<RatingRequestScreen> {
  bool _responded = false;
  bool _showThanks = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AnalyticsService>().logEvent('onboarding_rating_viewed');
      }
    });
  }

  Future<void> _handlePositive() async {
    if (_responded) return;
    setState(() {
      _responded = true;
      _showThanks = true;
    });

    final analytics = context.read<AnalyticsService>();
    analytics.logEvent('onboarding_rating_positive');

    try {
      final inAppReview = InAppReview.instance;
      final available = await inAppReview.isAvailable();
      analytics.logEvent('native_review_available', {'available': available});
      if (available) {
        await inAppReview.requestReview();
        analytics.logEvent('native_review_requested');
      }
    } catch (_) {
      analytics.logEvent('native_review_failed');
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));
    _continueToPaywall();
  }

  Future<void> _handleSkip(String reason) async {
    if (_responded) return;
    setState(() => _responded = true);
    context.read<AnalyticsService>().logEvent('onboarding_rating_skipped', {
      'reason': reason,
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _continueToPaywall();
  }

  void _continueToPaywall() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    router.go('/today');
    Future<void>.microtask(() => router.push('/paywall'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.sun.withValues(alpha: 0.28),
                      c.sun.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(color: c.sun.withValues(alpha: 0.36)),
                  boxShadow: [
                    BoxShadow(
                      color: c.sun.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Icon(Icons.star_rounded, color: c.sun, size: 58),
              ),
              const SizedBox(height: 30),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _showThanks
                      ? 'Thank you'
                      : 'Is BabyRelay already feeling helpful?',
                  key: ValueKey(_showThanks),
                  textAlign: TextAlign.center,
                  style: text.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _showThanks
                      ? 'Your support helps more tired caregivers find calmer handoffs.'
                      : 'If this would make handoffs calmer for your family, a quick rating helps other caregivers find it.',
                  key: ValueKey('body_$_showThanks'),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: c.inkSoft),
                ),
              ),
              const Spacer(),
              IgnorePointer(
                ignoring: _responded,
                child: AnimatedOpacity(
                  opacity: _responded ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    children: [
                      FilledButton.icon(
                        onPressed: _handlePositive,
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('Yes, love it'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _handleSkip('needs_work'),
                        child: const Text('Needs work'),
                      ),
                      TextButton(
                        onPressed: () => _handleSkip('maybe_later'),
                        child: const Text('Maybe later'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
