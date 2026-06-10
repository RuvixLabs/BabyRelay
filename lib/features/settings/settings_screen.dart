import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/purchases/purchase_service.dart';
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
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final state = repo.state;
    final now = DateTime.now();

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
                Divider(height: 1, indent: 60, color: c.outline),
                _SettingsRow(
                  icon: Icons.auto_fix_high,
                  iconColor: c.sun,
                  title: 'Load sample day',
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
                  title: purchases.isPro
                      ? 'BabyRelay Family${purchases.inTrial ? ' · trial' : ''}'
                      : 'Free plan',
                  subtitle: purchases.isPro
                      ? (purchases.activePlan == PlanId.annual
                            ? 'Annual · \$59.99/yr'
                            : 'Monthly · \$9.99/mo')
                      : 'First child + one extra caregiver',
                  trailing: purchases.isPro
                      ? RelayChip('Active', color: c.sage)
                      : RelayChip('Upgrade', color: c.clay),
                  onTap: () => context.push('/paywall'),
                ),
                if (purchases.isPro) ...[
                  Divider(height: 1, indent: 60, color: c.outline),
                  _SettingsRow(
                    icon: Icons.refresh,
                    iconColor: c.inkSoft,
                    title: 'Reset entitlement (demo)',
                    subtitle: 'Clears the mock subscription state',
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
              subtitle: 'In-app support arrives with the Gleap integration',
              onTap: () => _showPlaceholder(
                context,
                'Gleap',
                'The support widget connects here once the Gleap SDK key is configured.',
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Integrations (demo build)'),
          RelayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This build runs fully on-device. Production services plug in behind existing seams:',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                const _IntegrationRow(
                  'Firebase Auth · Firestore · Analytics · Crashlytics · Messaging',
                  'Repositories and the analytics wrapper are ready for it',
                ),
                const _IntegrationRow(
                  'RevenueCat',
                  'PurchaseService mirrors the entitlement API (`pro`)',
                ),
                const _IntegrationRow(
                  'AppRefer',
                  'Invite links will carry attribution',
                ),
                const _IntegrationRow('Gleap', 'Support entry point above'),
                const _IntegrationRow(
                  'AppStore Copilot',
                  'Store metadata pipeline',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              'BabyRelay 0.1.0 · prototype\nGuidance is scheduling support, not medical advice.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This permanently erases every child\'s profile, the full timeline, and the care team on this device. There is no undo.',
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

  void _showPlaceholder(BuildContext context, String name, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
  const _IntegrationRow(this.name, this.detail);

  final String name;
  final String detail;

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
              Icons.radio_button_unchecked,
              size: 12,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          RelayChip('Not connected', color: c.inkSoft),
        ],
      ),
    );
  }
}
