import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/config/app_config.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/legal/legal_links.dart';
import '../../core/purchases/purchase_service.dart';
import '../../core/support/support_service.dart';
import '../../data/family_repository.dart';
import '../../domain/models/baby_profile.dart';
import '../children/child_form_sheet.dart';
import '../children/child_switcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FamilyRepository>();
    final purchases = context.watch<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final support = context.read<SupportService>();
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final state = repo.state;
    final now = DateTime.now();
    final hasFamilyPlan = purchases.isPro || state.familySubscriptionActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('Children'),
          RelayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final child in state.children) ...[
                  _ChildSettingsRow(
                    child: child,
                    subtitle:
                        '${child.ageLabelAt(now)} · ${child.napsPerDayEstimate} nap${child.napsPerDayEstimate == 1 ? '' : 's'}/day',
                    selected: child.id == state.selectedChildId,
                    canRemove: state.children.length > 1,
                    onTap: () async {
                      final updated = await showChildFormSheet(
                        context,
                        existing: child,
                      );
                      if (updated != null) {
                        await repo.updateChild(updated);
                        analytics.logEvent('child_profile_edited');
                      }
                    },
                    onRemove: () =>
                        _confirmRemoveChild(context, repo, analytics, child),
                  ),
                  Divider(height: 1, indent: 60, color: c.outline),
                ],
                _SettingsRow(
                  icon: Icons.add,
                  iconColor: c.clayDeep,
                  title: 'Add a child',
                  subtitle: 'Same care team, their own timeline',
                  onTap: () => startAddChildFlow(context),
                ),
                // Demo seeding is a development tool; release builds never
                // show it.
                if (kDebugMode) ...[
                  Divider(height: 1, indent: 60, color: c.outline),
                  _SettingsRow(
                    icon: Icons.auto_fix_high,
                    iconColor: c.sun,
                    title: 'Load sample day (debug)',
                    subtitle: 'Fill today with believable demo data',
                    onTap: () async {
                      await repo.loadSampleDay();
                      analytics.logEvent('sample_day_loaded');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sample day loaded')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Subscription'),
          RelayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.workspace_premium_outlined,
                  iconColor: c.clay,
                  title: hasFamilyPlan
                      ? 'BabyRelay Family${purchases.inTrial ? ' · trial' : ''}'
                      : 'Free plan',
                  subtitle: purchases.isPro
                      ? switch (purchases.activePlan) {
                          PlanId.specialAnnual => 'Special annual · \$29.99/yr',
                          PlanId.annual => 'Annual · \$59.99/yr',
                          PlanId.monthly => 'Monthly · \$9.99/mo',
                          null => 'BabyRelay Family',
                        }
                      : state.familySubscriptionActive
                      ? 'Active for this care team'
                      : 'First child + one extra caregiver',
                  trailing: hasFamilyPlan
                      ? RelayChip('Active', color: c.sage)
                      : RelayChip('Upgrade', color: c.clay),
                  onTap: () => context.push('/paywall'),
                ),
                if (kDebugMode &&
                    purchases.isPro &&
                    purchases is LocalPurchaseService) ...[
                  Divider(height: 1, indent: 60, color: c.outline),
                  _SettingsRow(
                    icon: Icons.refresh,
                    iconColor: c.inkSoft,
                    title: 'Reset entitlement (debug)',
                    subtitle: 'Back to the free tier to re-test the paywall',
                    onTap: () => purchases.clearEntitlement(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Privacy & data'),
          RelayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.group_remove_outlined,
                  iconColor: c.dusk,
                  title: 'Caregiver access',
                  subtitle:
                      'Remove or revoke caregivers from the Care team tab',
                  onTap: () => context.go('/team'),
                ),
                Divider(height: 1, indent: 60, color: c.outline),
                _SettingsRow(
                  icon: Icons.download_outlined,
                  iconColor: c.sage,
                  title: 'Export my data',
                  subtitle: 'Copy everything as JSON',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: repo.exportJson()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data copied to clipboard as JSON'),
                        ),
                      );
                    }
                  },
                ),
                Divider(height: 1, indent: 60, color: c.outline),
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: c.clay,
                  title: 'Privacy Policy',
                  subtitle: 'How BabyRelay handles family data',
                  onTap: () =>
                      openLegalDocument(context, LegalDocument.privacy),
                ),
                Divider(height: 1, indent: 60, color: c.outline),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  iconColor: c.clayDeep,
                  title: 'Terms of Service',
                  subtitle: 'Subscriptions, use, and care guidance terms',
                  onTap: () => openLegalDocument(context, LegalDocument.terms),
                ),
                Divider(height: 1, indent: 60, color: c.outline),
                _SettingsRow(
                  icon: Icons.delete_forever_outlined,
                  iconColor: c.danger,
                  title: 'Delete all data',
                  subtitle: 'Erases every child, timeline, and the care team',
                  destructive: true,
                  onTap: () => _confirmDelete(context, repo, analytics),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Support'),
          RelayCard(
            padding: EdgeInsets.zero,
            child: _SettingsRow(
              icon: Icons.support_agent,
              iconColor: c.dusk,
              title: 'Contact support',
              subtitle: support.configured
                  ? 'Message us in the app'
                  : 'Email ${AppConfig.supportEmail}',
              onTap: () async {
                final opened = await support.openConversation(
                  userId: repo.syncUserId,
                );
                if (opened) {
                  analytics.logEvent('support_contacted', {'method': 'gleap'});
                  return;
                }
                analytics.logEvent('support_contacted', {'method': 'email'});
                await Clipboard.setData(
                  const ClipboardData(text: AppConfig.supportEmail),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Support email copied — we usually reply within a day',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          // Provider wiring status is developer-facing; users never need it.
          if (kDebugMode) ...[
            const SizedBox(height: 22),
            const SectionLabel('Connected services (debug)'),
            RelayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This build runs fully on-device. Each service switches on '
                    'when its key is supplied via --dart-define:',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final integration in Integrations.all)
                    _IntegrationRow(integration),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Center(
            child: Text(
              'BabyRelay ${AppConfig.appVersion}\nGuidance is scheduling support, not medical advice.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.inkFaint, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveChild(
    BuildContext context,
    FamilyRepository repo,
    AnalyticsService analytics,
    BabyProfile child,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${child.nickname}?'),
        content: const Text(
          'This permanently deletes this child\'s profile and their entire timeline for the whole care team. There is no undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove child'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.removeChild(child.id);
      analytics.logEvent('child_removed');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FamilyRepository repo,
    AnalyticsService analytics,
  ) async {
    final isOwner = repo.state.currentCaregiver?.isOwner == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete everything?'),
        content: Text(
          isOwner
              ? 'This permanently deletes the family, every child profile, the full timeline, your account, and all care-team access. There is no undo.'
              : 'This permanently leaves the care team and deletes your account and this device\'s private notification data. The shared family history remains for the owner. There is no undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.deleteAllData();
      analytics.logEvent('data_deleted');
    }
  }
}

class _ChildSettingsRow extends StatelessWidget {
  const _ChildSettingsRow({
    required this.child,
    required this.subtitle,
    required this.selected,
    required this.canRemove,
    required this.onTap,
    required this.onRemove,
  });

  final BabyProfile child;
  final String subtitle;
  final bool selected;
  final bool canRemove;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ChildAvatar(child: child, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          child.nickname,
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        RelayChip('Selected', color: c.sage),
                      ],
                    ],
                  ),
                  Text(subtitle, style: text.bodyMedium),
                ],
              ),
            ),
            if (canRemove)
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.inkFaint, size: 20),
                tooltip: 'Remove child',
                onPressed: onRemove,
              ),
            Icon(Icons.chevron_right, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final color = destructive ? c.danger : c.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            IconSquare(
              icon: icon,
              color: destructive ? c.danger : (iconColor ?? c.inkSoft),
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: color),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow(this.integration);

  final Integration integration;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              integration.configured
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 12,
              color: integration.configured ? c.sage : c.inkFaint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  integration.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  integration.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          RelayChip(
            integration.configured ? 'Configured' : 'Not configured',
            color: integration.configured ? c.sage : c.inkSoft,
          ),
        ],
      ),
    );
  }
}
