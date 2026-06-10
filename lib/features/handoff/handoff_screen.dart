import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../data/family_repository.dart';
import '../../domain/engine/sleep_prediction_engine.dart';
import '../../domain/models/baby_profile.dart';
import '../../domain/services/day_context_builder.dart';
import '../../domain/services/handoff_service.dart';

/// The relay moment: a plain-language summary the next caregiver can read in
/// ten seconds, shareable as text so non-app grandparents still get it.
/// Always scoped to the selected child.
class HandoffScreen extends StatelessWidget {
  const HandoffScreen({super.key});

  HandoffSummary? _buildSummary(FamilyRepository repo, BabyProfile? child) {
    final state = repo.state;
    if (child == null) return null;
    final now = DateTime.now();
    const engine = SleepPredictionEngine();
    const dayBuilder = DayContextBuilder();
    final prediction = engine.predict(
      dayBuilder.build(
        baby: child,
        events: state.eventsForChild(child.id),
        now: now,
        recentNapCounts: repo.recentNapCounts(now: now, childId: child.id),
        assumeAwakeNow: state.isChildAsleep(child.id),
      ),
    );
    return const HandoffService().build(
      babyName: child.nickname,
      now: now,
      todayEvents: state.eventsOn(now, childId: child.id),
      caregiverNames: {for (final c in state.caregivers) c.id: c.name},
      prediction: prediction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final repo = context.watch<FamilyRepository>();
    final analytics = context.read<AnalyticsService>();
    final child = repo.state.selectedChild;
    final summary = _buildSummary(repo, child);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Handoff'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: summary == null || child == null
          ? const Center(child: Text('Set up your child\'s profile first.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Everything the next caregiver needs, in one glance.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                // The relay note. Deep header band makes it feel like a
                // designed artifact, not another list.
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: c.outline),
                    boxShadow: [
                      BoxShadow(
                        color: c.ink.withValues(alpha: 0.06),
                        blurRadius: 22,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(gradient: c.nightGradient),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                        child: Row(
                          children: [
                            ChildAvatar(child: child, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summary.headline.toUpperCase(),
                                    style: text.labelSmall?.copyWith(
                                      color: c.onNightSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    summary.statusLine,
                                    style: text.titleMedium?.copyWith(
                                      color: c.onNight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in summary.lines) ...[
                              _SummaryLine(line: line),
                              const SizedBox(height: 10),
                            ],
                            Divider(color: c.outline, height: 28),
                            Text(
                              'FOR THE NEXT CAREGIVER',
                              style: text.labelSmall,
                            ),
                            const SizedBox(height: 10),
                            for (final line in summary.headsUp) ...[
                              _SummaryLine(
                                line: line,
                                icon: Icons.tips_and_updates_outlined,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    analytics.logEvent('handoff_shared', {'method': 'share'});
                    SharePlus.instance.share(
                      ShareParams(text: summary.shareText),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share handoff'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () async {
                    analytics.logEvent('handoff_shared', {'method': 'copy'});
                    await Clipboard.setData(
                      ClipboardData(text: summary.shareText),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Handoff copied — paste it anywhere'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy as text'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Works for anyone — the text version reads fine in any messaging app, no BabyRelay account needed.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: c.inkFaint),
                ),
              ],
            ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line, this.icon});

  final String line;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            icon ?? Icons.circle,
            size: icon == null ? 8 : 18,
            color: icon == null ? c.clay : c.sun,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(line, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
