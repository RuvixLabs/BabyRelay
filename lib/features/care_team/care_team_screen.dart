import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_chrome.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/purchases/purchase_service.dart';
import '../../core/tutorial/coach_marks.dart';
import '../../core/tutorial/tutorial_service.dart';
import '../../core/util/formats.dart';
import '../../data/family_repository.dart';
import '../../domain/models/caregiver.dart';
import '../../domain/services/invite_service.dart';

/// Free tier covers the core duo (owner + one caregiver). Growing the team
/// beyond that is the BabyRelay Family upgrade moment.
const int kFreeCaregiverLimit = FamilyRepository.freeCaregiverLimit;

class CareTeamScreen extends StatefulWidget {
  const CareTeamScreen({super.key});

  @override
  State<CareTeamScreen> createState() => _CareTeamScreenState();
}

class _CareTeamScreenState extends State<CareTeamScreen> {
  final _inviteKey = GlobalKey(debugLabel: 'coach-care-team-invite');
  final _howItWorksKey = GlobalKey(debugLabel: 'coach-care-team-how-it-works');
  bool _tourQueued = false;

  void _queueTour(BuildContext context) {
    if (_tourQueued) return;
    final tutorial = context.read<TutorialService>();
    if (!tutorial.shouldShow(TutorialIds.careTeam)) return;
    _tourQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!tutorial.shouldShow(TutorialIds.careTeam)) return;
      final analytics = context.read<AnalyticsService>();
      analytics.logEvent('coach_mark_seen', {'section': TutorialIds.careTeam});
      final result = await showCoachMarks(
        context: context,
        steps: [
          CoachMarkStep(
            targetKey: _inviteKey,
            title: 'Invite the people who help',
            body:
                'Partners, grandparents, nannies, and sitters can join the same shared baby log.',
            icon: Icons.person_add_alt_1,
          ),
          CoachMarkStep(
            targetKey: _howItWorksKey,
            title: 'Everyone stays in sync',
            body:
                'Each log shows who added it, so the next caregiver can take over with context.',
            icon: Icons.sync_rounded,
          ),
        ],
      );
      if (!mounted) return;
      await tutorial.markSeen(TutorialIds.careTeam);
      analytics.logEvent(
        result == CoachMarkResult.completed
            ? 'coach_mark_completed'
            : 'coach_mark_skipped',
        {'section': TutorialIds.careTeam},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _queueTour(context);
    final repo = context.watch<FamilyRepository>();
    final purchases = context.watch<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final state = repo.state;
    final active = state.activeCaregivers;
    final isOwner = state.currentCaregiver?.isOwner ?? false;
    final text = Theme.of(context).textTheme;
    final c = context.relay;

    Future<void> startInvite() async {
      analytics.logEvent('caregiver_invite_started');
      if (!purchases.isPro && active.length >= kFreeCaregiverLimit) {
        context.push('/paywall');
        return;
      }
      await showInviteSheet(context, repo, analytics);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Care team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            state.children.length > 1
                ? 'Everyone here sees every child\'s timeline, live.'
                : 'Everyone caring for ${state.selectedChild?.nickname ?? 'your baby'} sees the same timeline, live.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          const SectionLabel('On the team'),
          RelayCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 64, color: c.outline),
                  _MemberRow(
                    caregiver: active[i],
                    isYou: active[i].id == state.currentCaregiverId,
                    canRemove:
                        isOwner && active[i].id != state.currentCaregiverId,
                    onRemove: () =>
                        _confirmRemove(context, repo, analytics, active[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: _inviteKey,
            child: FilledButton.icon(
              onPressed: startInvite,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite a caregiver'),
            ),
          ),
          if (!purchases.isPro && active.length >= kFreeCaregiverLimit) ...[
            const SizedBox(height: 10),
            RelayCard(
              padding: const EdgeInsets.all(16),
              color: c.claySoft,
              borderColor: c.clay.withValues(alpha: 0.3),
              onTap: () => context.push('/paywall'),
              child: Row(
                children: [
                  IconSquare(
                    icon: Icons.workspace_premium_outlined,
                    color: c.clayDeep,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Growing care team?', style: text.titleMedium),
                        Text(
                          'Unlimited caregivers and children with BabyRelay Family.',
                          style: text.bodyMedium?.copyWith(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.clayDeep),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('How invites work'),
          KeyedSubtree(
            key: _howItWorksKey,
            child: RelayCard(
              child: Column(
                children: const [
                  _HowItWorksRow(
                    icon: Icons.qr_code_2,
                    title: 'Share the code',
                    body: 'Show the QR or send the 6-letter code or link.',
                  ),
                  SizedBox(height: 14),
                  _HowItWorksRow(
                    icon: Icons.download_outlined,
                    title: 'They join in under a minute',
                    body:
                        'They install BabyRelay, enter the code, and pick a name.',
                  ),
                  SizedBox(height: 14),
                  _HowItWorksRow(
                    icon: Icons.sync,
                    title: 'Everything stays in sync',
                    body:
                        'Every log shows who did it. No more "when did she last eat?" texts.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    FamilyRepository repo,
    AnalyticsService analytics,
    Caregiver caregiver,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${caregiver.name}?'),
        content: const Text(
          'They lose access to the timeline immediately. Entries they logged stay, with their attribution.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.removeCaregiver(caregiver.id);
      analytics.logEvent('caregiver_removed');
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.caregiver,
    required this.isYou,
    required this.canRemove,
    required this.onRemove,
  });

  final Caregiver caregiver;
  final bool isYou;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final lastActive = caregiver.lastActiveAt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CaregiverDot(caregiver: caregiver, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isYou ? '${caregiver.name} (you)' : caregiver.name,
                        style: text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RelayChip(
                      caregiver.isOwner ? 'Owner' : 'Caregiver',
                      color: caregiver.isOwner ? c.clay : c.sage,
                    ),
                  ],
                ),
                Text(
                  lastActive == null
                      ? 'No activity yet'
                      : 'Active ${formatRelative(lastActive, DateTime.now())}',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              icon: Icon(Icons.person_remove_outlined, color: c.danger),
              tooltip: 'Remove access',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.clay.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: c.clayDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              Text(body, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Invite sheet

Future<void> showInviteSheet(
  BuildContext context,
  FamilyRepository repo,
  AnalyticsService analytics,
) {
  return showRelayModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _InviteSheet(repo: repo, analytics: analytics),
  );
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.repo, required this.analytics});

  final FamilyRepository repo;
  final AnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final invite = const InviteService().buildInvite(repo.state.inviteCode);
    final code = invite.code;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invite a caregiver', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Share this code or copy the invite link.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.outline),
              ),
              child: QrImageView(
                data: invite.url.toString(),
                size: 160,
                padding: EdgeInsets.zero,
                backgroundColor: c.surfaceRaised,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.ink),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: c.ink,
                ),
                semanticsLabel: 'BabyRelay caregiver invite QR code',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              code.split('').join(' '),
              style: text.displayMedium?.copyWith(
                letterSpacing: 0,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                analytics.logEvent('caregiver_invite_sent', {'method': 'link'});
                await Clipboard.setData(ClipboardData(text: invite.shareText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied')),
                  );
                }
              },
              icon: const Icon(Icons.link),
              label: Text(invite.displayLink),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await repo.regenerateInviteCode();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Generate a new code'),
            ),
            if (!repo.syncConfigured) ...[
              Divider(color: c.outline, height: 28),
              // Local-preview stand-in for the real second-device join flow.
              // Production Firebase builds use only the QR/link/code path.
              TextButton.icon(
                onPressed: () async {
                  final name = await _askName(context);
                  if (name == null || name.trim().isEmpty) return;
                  await repo.addCaregiver(name);
                  analytics.logEvent('caregiver_joined');
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name joined the care team')),
                    );
                  }
                },
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add caregiver on this device'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _askName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add caregiver'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Their name (e.g. Grandma Ann)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
