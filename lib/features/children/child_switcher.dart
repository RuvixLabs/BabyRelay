import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_chrome.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/purchases/purchase_service.dart';
import '../../data/family_repository.dart';
import '../../domain/models/baby_profile.dart';
import 'child_form_sheet.dart';

/// Free tier covers one child; brothers and sisters join with BabyRelay
/// Family.
const int kFreeChildLimit = 1;

/// Starts the add-child flow, gating on the paywall beyond the free limit.
/// Returns the new child, or null if cancelled/gated.
Future<BabyProfile?> startAddChildFlow(BuildContext context) async {
  final repo = context.read<FamilyRepository>();
  final purchases = context.read<PurchaseService>();
  final analytics = context.read<AnalyticsService>();
  if (!purchases.isPro && repo.state.children.length >= kFreeChildLimit) {
    context.push('/paywall');
    return null;
  }
  final draft = await showChildFormSheet(context);
  if (draft == null) return null;
  final added = await repo.addChild(draft);
  analytics.logEvent('child_added');
  return added;
}

/// Bottom sheet listing every child with sleep state; tap to switch, plus an
/// add-child row. The one place the whole family is visible at once.
Future<void> showChildSwitcherSheet(BuildContext context) {
  return showRelayModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<FamilyRepository>()),
        ChangeNotifierProvider.value(value: context.read<PurchaseService>()),
        Provider.value(value: context.read<AnalyticsService>()),
      ],
      child: const _ChildSwitcherSheet(),
    ),
  );
}

class _ChildSwitcherSheet extends StatelessWidget {
  const _ChildSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<FamilyRepository>();
    final analytics = context.read<AnalyticsService>();
    final state = repo.state;
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your children', style: text.titleLarge),
            const SizedBox(height: 2),
            Text(
              'One care team, a timeline for each child.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 14),
            for (final child in state.children) ...[
              _ChildRow(
                child: child,
                selected: child.id == state.selectedChildId,
                asleep: state.isChildAsleep(child.id),
                ageLabel: child.ageLabelAt(now),
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await repo.selectChild(child.id);
                  analytics.logEvent('child_switched');
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
            InkWell(
              onTap: () async {
                final added = await startAddChildFlow(context);
                if (added != null && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.claySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: c.clayDeep, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Add a child', style: text.titleMedium),
                    ),
                    Icon(Icons.chevron_right, color: c.inkFaint),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.child,
    required this.selected,
    required this.asleep,
    required this.ageLabel,
    required this.onTap,
  });

  final BabyProfile child;
  final bool selected;
  final bool asleep;
  final String ageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final accent = c.avatarColor(child.colorIndex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.55) : c.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            ChildAvatar(child: child, size: 44, asleep: asleep),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.nickname, style: text.titleMedium),
                  Text(
                    asleep ? '$ageLabel · asleep now' : ageLabel,
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal child strip for the Today header. Hidden for
/// single-child families; one tap switches, the trailing chip opens the
/// switcher sheet for managing the family.
class ChildSwitcherStrip extends StatelessWidget {
  const ChildSwitcherStrip({
    super.key,
    required this.children,
    required this.selectedChildId,
    required this.isAsleepById,
    required this.onSelect,
    required this.onManage,
  });

  final List<BabyProfile> children;
  final String selectedChildId;
  final bool Function(String childId) isAsleepById;
  final ValueChanged<String> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    if (children.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final child in children) ...[
            _ChildPill(
              child: child,
              selected: child.id == selectedChildId,
              asleep: isAsleepById(child.id),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(child.id);
              },
            ),
            const SizedBox(width: 8),
          ],
          InkWell(
            onTap: onManage,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.outline),
                color: c.surface,
              ),
              child: Icon(Icons.add, size: 20, color: c.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildPill extends StatelessWidget {
  const _ChildPill({
    required this.child,
    required this.selected,
    required this.asleep,
    required this.onTap,
  });

  final BabyProfile child;
  final bool selected;
  final bool asleep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final accent = c.avatarColor(child.colorIndex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : c.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.6) : c.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChildAvatar(child: child, size: 30, asleep: asleep),
            const SizedBox(width: 8),
            Text(
              child.nickname,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Color.lerp(accent, c.ink, 0.4) : c.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
