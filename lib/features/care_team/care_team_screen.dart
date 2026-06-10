import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/purchases/purchase_service.dart';
import '../../core/util/formats.dart';
import '../../data/family_repository.dart';
import '../../domain/models/caregiver.dart';

/// Free tier covers the core duo (owner + one caregiver). Growing the team
/// beyond that is the BabyRelay Family upgrade moment.
const int kFreeCaregiverLimit = 2;

class CareTeamScreen extends StatelessWidget {
  const CareTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            'Everyone caring for ${state.baby?.nickname ?? 'your baby'} sees the same timeline, live.',
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
          FilledButton.icon(
            onPressed: startInvite,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Invite a caregiver'),
          ),
          if (!purchases.isPro && active.length >= kFreeCaregiverLimit) ...[
            const SizedBox(height: 8),
            Text(
              'Unlimited caregivers is part of BabyRelay Family.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.inkFaint),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('How invites work'),
          RelayCard(
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
  return showModalBottomSheet<void>(
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
    final code = repo.state.inviteCode;
    final link = 'babyrelay.app/join/$code';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invite a caregiver', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'They scan this or enter the code in their app.',
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
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _CodeGlyphPainter(code: code, color: c.ink),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              code.split('').join(' '),
              style: text.displayMedium?.copyWith(
                letterSpacing: 6,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                analytics.logEvent('caregiver_invite_sent', {'method': 'link'});
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'Join me on BabyRelay so we both see the baby\'s day: https://$link',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied')),
                  );
                }
              },
              icon: const Icon(Icons.link),
              label: Text(link),
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
            Divider(color: c.outline, height: 28),
            // Demo-build stand-in for the real join flow: the second device
            // would enter the code; here we add them directly so the shared
            // timeline can be exercised end to end.
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
              label: const Text('They\'re here with me — add directly'),
            ),
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

/// Deterministic QR-style glyph derived from the invite code. Not a scannable
/// QR (the real one ships with the deep-link integration) but reads as one and
/// keeps the sheet feeling complete.
class _CodeGlyphPainter extends CustomPainter {
  _CodeGlyphPainter({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 11;
    final cell = size.width / grid;
    final paint = Paint()..color = color;

    int seed = 0;
    for (final unit in code.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }

    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    // Symmetric module pattern (mirrored left/right) so it looks designed.
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x <= grid ~/ 2; x++) {
        final filled = next() % 5 < 2;
        if (!filled) continue;
        final rect = Rect.fromLTWH(x * cell, y * cell, cell - 1.5, cell - 1.5);
        final mirrored = Rect.fromLTWH(
          (grid - 1 - x) * cell,
          y * cell,
          cell - 1.5,
          cell - 1.5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(mirrored, const Radius.circular(2)),
          paint,
        );
      }
    }

    // Corner finder squares, like a real QR.
    for (final corner in [
      Offset.zero,
      Offset(size.width - 3 * cell, 0),
      Offset(0, size.height - 3 * cell),
    ]) {
      final outer = Rect.fromLTWH(corner.dx, corner.dy, cell * 3, cell * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer, const Radius.circular(4)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.6,
      );
      final inner = Rect.fromLTWH(
        corner.dx + cell,
        corner.dy + cell,
        cell,
        cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CodeGlyphPainter oldDelegate) =>
      oldDelegate.code != code || oldDelegate.color != color;
}
