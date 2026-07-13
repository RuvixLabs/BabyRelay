import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/legal/legal_links.dart';
import '../../core/purchases/purchase_service.dart';
import '../../core/tutorial/tutorial_service.dart';
import '../../data/family_repository.dart';

/// Family paywall. Calm and honest: price, trial terms, and the limited launch
/// offer window are stated plainly, and close is always available.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.placement = 'settings_upgrade'});

  final String placement;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PlanId _selected = PlanId.specialAnnual;
  Timer? _countdownTimer;
  DateTime? _specialOfferEndsAt;
  int _offerRemainingSeconds = 0;
  bool _timerConfigured = false;
  bool _remotePresentationStarted = false;
  bool _remotePresentationFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AnalyticsService>().logEvent('paywall_viewed');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final purchases = context.read<PurchaseService>();
    if (purchases.usesRemotePaywalls) {
      if (!_remotePresentationStarted) {
        _remotePresentationStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _presentRemotePaywall();
        });
      }
      return;
    }
    if (_timerConfigured) return;
    _timerConfigured = true;

    Plan? specialPlan;
    for (final plan in purchases.plans) {
      if (plan.isSpecialOffer && plan.countdownSeconds != null) {
        specialPlan = plan;
        break;
      }
    }
    final seconds = specialPlan?.countdownSeconds ?? 0;
    if (seconds <= 0) return;

    _offerRemainingSeconds = seconds;
    _specialOfferEndsAt = DateTime.now().add(Duration(seconds: seconds));
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickOfferTimer(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _tickOfferTimer() {
    final endsAt = _specialOfferEndsAt;
    if (!mounted || endsAt == null) return;

    final next = endsAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    if (next == _offerRemainingSeconds) return;
    setState(() => _offerRemainingSeconds = next);
    if (next == 0) _countdownTimer?.cancel();
  }

  Future<void> _purchase() async {
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final repo = context.read<FamilyRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final plan = purchases.plans.firstWhere((p) => p.id == _selected);
    analytics.logEvent('purchase_started', {'plan': plan.id.name});
    final outcome = await purchases.purchase(plan);
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        analytics.logEvent('purchase_completed', {'plan': plan.id.name});
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              plan.trialDays > 0
                  ? 'Welcome to BabyRelay Family — trial started'
                  : 'Welcome to BabyRelay Family',
            ),
          ),
        );
        _dismissPaywall();
        _syncFamilySubscription(repo, plan.id.name);
        break;
      case PurchaseOutcome.cancelled:
        // Backing out of the store sheet is not an error; stay quiet.
        analytics.logEvent('purchase_cancelled', {'plan': plan.id.name});
        break;
      case PurchaseOutcome.failed:
        analytics.logEvent('purchase_failed', {'plan': plan.id.name});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              purchases.lastErrorMessage ??
                  'The purchase could not be completed. Please try again.',
            ),
          ),
        );
        break;
    }
  }

  Future<void> _presentRemotePaywall() async {
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final repo = context.read<FamilyRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _remotePresentationFailed = false);
    analytics.logEvent('superwall_placement_registered', {
      'placement': widget.placement,
    });
    final outcome = await purchases.presentPaywall(
      widget.placement,
      params: {'source': widget.placement},
    );
    if (!mounted) return;
    switch (outcome) {
      case PaywallOutcome.purchased:
        analytics.logEvent('purchase_completed', {
          'placement': widget.placement,
          'plan': purchases.activePlan?.name ?? 'store_product',
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Welcome to BabyRelay Family')),
        );
        _syncFamilySubscription(repo, purchases.activePlan?.name ?? '');
        _dismissPaywall();
      case PaywallOutcome.restored:
        analytics.logEvent('restore_completed', {
          'placement': widget.placement,
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Purchases restored')),
        );
        _syncFamilySubscription(repo, purchases.activePlan?.name ?? '');
        _dismissPaywall();
      case PaywallOutcome.dismissed:
      case PaywallOutcome.skipped:
        _dismissPaywall();
      case PaywallOutcome.failed:
        analytics.logEvent('paywall_failed', {'placement': widget.placement});
        setState(() => _remotePresentationFailed = true);
    }
  }

  Future<void> _restore() async {
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final repo = context.read<FamilyRepository>();
    final messenger = ScaffoldMessenger.of(context);
    analytics.logEvent('restore_tapped');
    final outcome = await purchases.restore();
    if (!mounted) return;
    switch (outcome) {
      case RestoreOutcome.restored:
        analytics.logEvent('restore_completed');
        messenger.showSnackBar(
          const SnackBar(content: Text('Purchases restored')),
        );
        _dismissPaywall();
        _syncFamilySubscription(repo, purchases.activePlan?.name ?? '');
        break;
      case RestoreOutcome.nothingToRestore:
        analytics.logEvent('restore_empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchase found')),
        );
        break;
      case RestoreOutcome.failed:
        analytics.logEvent('restore_failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              purchases.lastErrorMessage ??
                  'Could not reach the store. Please try again.',
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final purchases = context.watch<PurchaseService>();

    if (purchases.usesRemotePaywalls) {
      return _RemotePaywallLauncher(
        failed: _remotePresentationFailed,
        busy: purchases.busy,
        errorMessage: purchases.lastErrorMessage,
        onRetry: () {
          if (!purchases.busy) _presentRemotePaywall();
        },
        onRestore: purchases.busy ? null : _restore,
        onClose: _dismissPaywall,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                    children: [
                      const _PaywallHero(),
                      const SizedBox(height: 10),
                      Text(
                        'The whole care team,\non the same page',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'BabyRelay Family keeps every caregiver in sync — choose the launch offer, annual trial, or monthly plan.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      for (final plan in purchases.plans) ...[
                        _PlanTile(
                          plan: plan,
                          selected: _selected == plan.id,
                          offerRemainingSeconds: plan.isSpecialOffer
                              ? _offerRemainingSeconds
                              : null,
                          onTap: () {
                            setState(() => _selected = plan.id);
                            context.read<AnalyticsService>().logEvent(
                              'plan_selected',
                              {'plan': plan.id.name},
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      const _FeatureGrid(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                    children: [
                      FilledButton(
                        onPressed: purchases.busy ? null : _purchase,
                        child: purchases.busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(_ctaLabel(purchases)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _billingCopy(purchases),
                        style: text.bodyMedium?.copyWith(fontSize: 13),
                      ),
                      TextButton(
                        onPressed: purchases.busy ? null : _restore,
                        child: const Text('Restore purchases'),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          TextButton(
                            onPressed: () => openLegalDocument(
                              context,
                              LegalDocument.privacy,
                            ),
                            child: const Text('Privacy'),
                          ),
                          Text(
                            '•',
                            style: text.bodySmall?.copyWith(color: c.inkFaint),
                          ),
                          TextButton(
                            onPressed: () =>
                                openLegalDocument(context, LegalDocument.terms),
                            child: const Text('Terms'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: c.inkSoft),
                onPressed: _dismissPaywall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissPaywall() {
    final tutorials = context.read<TutorialService>();
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tutorials.requestVisibleTutorialCheck();
    });
  }

  void _syncFamilySubscription(FamilyRepository repo, String planId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        repo
            .setFamilySubscriptionStatus(active: true, planId: planId)
            .catchError((Object error, StackTrace stack) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stack,
                  library: 'BabyRelay purchases',
                  context: ErrorDescription(
                    'syncing family subscription status',
                  ),
                ),
              );
            }),
      );
    });
  }

  String _ctaLabel(PurchaseService purchases) {
    final plan = purchases.plans.firstWhere((p) => p.id == _selected);
    if (plan.trialDays > 0) return 'Start 7-day free trial';
    return switch (plan.id) {
      PlanId.specialAnnual => 'Claim annual offer',
      PlanId.annual => 'Choose annual',
      PlanId.monthly => 'Choose monthly',
    };
  }

  String _billingCopy(PurchaseService purchases) {
    final plan = purchases.plans.firstWhere((p) => p.id == _selected);
    if (plan.trialDays > 0) {
      return 'Free for ${plan.trialDays} days, then ${plan.priceLabel}${plan.id == PlanId.monthly ? '/month' : '/year'}. Cancel anytime.';
    }
    final period = plan.id == PlanId.monthly ? 'month' : 'year';
    return '${plan.priceLabel}/$period today. Cancel anytime.';
  }
}

class _RemotePaywallLauncher extends StatelessWidget {
  const _RemotePaywallLauncher({
    required this.failed,
    required this.busy,
    required this.errorMessage,
    required this.onRetry,
    required this.onRestore,
    required this.onClose,
  });

  final bool failed;
  final bool busy;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback? onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (failed) ...[
                      Icon(Icons.cloud_off_outlined, color: c.clay, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        'Couldn\'t load BabyRelay Family',
                        textAlign: TextAlign.center,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage ??
                            'Check your connection and try again. You can always close and continue with the free plan.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: busy ? null : onRetry,
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: onRestore,
                        child: const Text('Restore purchases'),
                      ),
                    ] else ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text('Loading BabyRelay Family…', style: text.bodyLarge),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: c.inkSoft),
                tooltip: 'Continue with free plan',
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Image.asset(
        'assets/images/generated/babyrelay_paywall_hero.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _features = [
    _Feature(Icons.group_add_outlined, 'Care team'),
    _Feature(Icons.child_care_outlined, 'More children'),
    _Feature(Icons.group_outlined, 'More caregivers'),
    _Feature(Icons.swap_horiz_rounded, 'Handoff summaries'),
    _Feature(Icons.sync_rounded, 'Family sync'),
    _Feature(Icons.route_outlined, 'Nap guidance'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final feature in _features) _FeatureChip(feature: feature),
      ],
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Container(
      width: (MediaQuery.sizeOf(context).width - 56) / 2,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Icon(feature.icon, color: c.sage, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    this.offerRemainingSeconds,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final int? offerRemainingSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: plan.isSpecialOffer
              ? c.nightLow
              : selected
              ? c.clay.withValues(alpha: 0.10)
              : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: plan.isSpecialOffer
                ? c.sun
                : selected
                ? c.clay
                : c.outline,
            width: selected ? 2 : 1,
          ),
          boxShadow: plan.isSpecialOffer
              ? [
                  BoxShadow(
                    color: c.sun.withValues(alpha: selected ? 0.25 : 0.12),
                    blurRadius: selected ? 24 : 14,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: plan.isSpecialOffer
                  ? c.sun
                  : selected
                  ? c.clayDeep
                  : c.inkFaint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.title,
                          style: text.titleMedium?.copyWith(
                            color: plan.isSpecialOffer ? c.onNight : null,
                          ),
                        ),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: plan.isSpecialOffer ? c.sun : c.sage,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            plan.badge!,
                            style: TextStyle(
                              color: plan.isSpecialOffer
                                  ? c.nightLow
                                  : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.subline != null)
                    Text(
                      plan.subline!,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: plan.isSpecialOffer ? c.onNightSoft : null,
                      ),
                    ),
                  if (plan.isSpecialOffer && offerRemainingSeconds != null) ...[
                    const SizedBox(height: 8),
                    _OfferTimerPill(seconds: offerRemainingSeconds!),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (plan.originalPriceLabel != null)
                  Text(
                    plan.originalPriceLabel!,
                    style: text.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: c.onNightSoft,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: c.onNightSoft,
                    ),
                  ),
                Text(
                  plan.priceLabel,
                  style: text.titleMedium?.copyWith(
                    color: plan.isSpecialOffer ? c.onNight : null,
                  ),
                ),
                Text(
                  plan.periodLabel,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: plan.isSpecialOffer ? c.onNightSoft : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferTimerPill extends StatelessWidget {
  const _OfferTimerPill({required this.seconds});

  final int seconds;

  String get _label {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.sun.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 15, color: c.sun),
          const SizedBox(width: 6),
          Text(
            'Offer ends in',
            style: text.bodyMedium?.copyWith(
              color: c.onNightSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: text.bodyMedium?.copyWith(
              color: c.onNight,
              fontSize: 12.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
