import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/purchases/purchase_service.dart';

/// Trial-first family paywall. Calm and honest: price and trial terms are
/// stated plainly, close is always available, no fake urgency.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PlanId _selected = PlanId.annual;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AnalyticsService>().logEvent('paywall_viewed');
    });
  }

  Future<void> _purchase() async {
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final plan = PurchaseService.plans.firstWhere((p) => p.id == _selected);
    analytics.logEvent('purchase_started', {'plan': plan.id.name});
    final result = await purchases.purchase(plan);
    if (!mounted) return;
    if (result == PurchaseResult.success) {
      analytics.logEvent('purchase_completed', {'plan': plan.id.name});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to BabyRelay Family — trial started'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      analytics.logEvent('purchase_failed', {'plan': plan.id.name});
    }
  }

  Future<void> _restore() async {
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    analytics.logEvent('restore_tapped');
    final restored = await purchases.restore();
    if (!mounted) return;
    if (restored) analytics.logEvent('restore_completed');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored ? 'Purchases restored' : 'No previous purchase found',
        ),
      ),
    );
    if (restored) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final purchases = context.watch<PurchaseService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: IconButton(
                  icon: Icon(Icons.close, color: c.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Warm illustration moment: overlapping caregiver circles.
                  SizedBox(height: 84, child: _CareCircles()),
                  const SizedBox(height: 20),
                  Text(
                    'The whole care team,\non the same page',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BabyRelay Family keeps every caregiver in sync — try it free for 7 days.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  const _ValueProp(
                    icon: Icons.group_add_outlined,
                    label: 'Unlimited caregivers',
                  ),
                  const _ValueProp(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Shareable handoff sheets',
                  ),
                  const _ValueProp(
                    icon: Icons.notifications_active_outlined,
                    label: 'Cross-caregiver notifications',
                  ),
                  const _ValueProp(
                    icon: Icons.history,
                    label: 'Full history, beyond today',
                  ),
                  const _ValueProp(
                    icon: Icons.route_outlined,
                    label: 'Nap transition guidance',
                  ),
                  const _ValueProp(
                    icon: Icons.ios_share,
                    label: 'Export and share summaries',
                  ),
                  const SizedBox(height: 20),
                  for (final plan in PurchaseService.plans) ...[
                    _PlanTile(
                      plan: plan,
                      selected: _selected == plan.id,
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
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Start 7-day free trial'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selected == PlanId.annual
                        ? 'Free for 7 days, then \$59.99/year. Cancel anytime.'
                        : 'Free for 7 days, then \$9.99/month. Cancel anytime.',
                    style: text.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  TextButton(
                    onPressed: purchases.busy ? null : _restore,
                    child: const Text('Restore purchases'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueProp extends StatelessWidget {
  const _ValueProp({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.sage.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: c.sage),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
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
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? c.clay.withValues(alpha: 0.10) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.clay : c.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? c.clayDeep : c.inkFaint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.title, style: text.titleMedium),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.sage,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            plan.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (plan.subline != null)
                    Text(plan.subline!, style: text.bodyMedium),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.priceLabel, style: text.titleMedium),
                Text(
                  plan.periodLabel,
                  style: text.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping warm circles standing in for the care team — no asset needed.
class _CareCircles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final colors = c.avatarPalette;
    return Center(
      child: SizedBox(
        width: 200,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Positioned(
                left: 20.0 + i * 40,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length].withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors[i % colors.length],
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    [
                      Icons.favorite,
                      Icons.nightlight_round,
                      Icons.local_drink_outlined,
                      Icons.swap_horiz_rounded,
                    ][i],
                    color: colors[i % colors.length],
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
