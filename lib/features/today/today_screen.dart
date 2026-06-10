import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/util/formats.dart';
import '../../data/family_repository.dart';
import '../../domain/models/care_event.dart';
import '../children/child_switcher.dart';
import '../timeline/event_edit_sheet.dart';
import 'today_cubit.dart';
import 'widgets/next_up_card.dart';
import 'widgets/quick_log_sheets.dart';
import 'widgets/sleep_button.dart';
import 'widgets/timeline_list.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TodayCubit(
        context.read<FamilyRepository>(),
        context.read<AnalyticsService>(),
      ),
      child: const _TodayView(),
    );
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView();

  String _greeting(DateTime now) {
    if (now.hour < 5) return 'Late night shift';
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    if (now.hour < 21) return 'Good evening';
    return 'Night shift';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<TodayCubit, TodayState>(
      builder: (context, state) {
        final cubit = context.read<TodayCubit>();
        final child = state.child;
        final caregivers = state.family.activeCaregivers;
        final you = state.family.currentCaregiver;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                // Header: who you're caring for + who else is around.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            you == null
                                ? _greeting(state.now)
                                : '${_greeting(state.now)}, ${you.name}',
                            style: text.labelSmall?.copyWith(color: c.clayDeep),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => showChildSwitcherSheet(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    child?.nickname ?? 'Baby',
                                    style: text.displayMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Icon(
                                    Icons.expand_more_rounded,
                                    color: c.inkFaint,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (child != null)
                            Text(
                              child.ageLabelAt(state.now),
                              style: text.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: _PresenceStack(caregivers: caregivers),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ChildSwitcherStrip(
                  children: state.children,
                  selectedChildId: state.family.selectedChildId,
                  isAsleepById: state.family.isChildAsleep,
                  onSelect: cubit.selectChild,
                  onManage: () => showChildSwitcherSheet(context),
                ),
                if (state.children.length > 1) const SizedBox(height: 12),
                // Handoff is the product promise — keep it one tap from home.
                _HandoffPill(
                  onTap: () {
                    context.read<AnalyticsService>().logEvent('handoff_opened');
                    context.push('/handoff');
                  },
                ),
                const SizedBox(height: 16),
                NextUpCard(
                  now: state.now,
                  childName: child?.nickname,
                  prediction: state.prediction,
                  ongoingSleep: state.ongoingSleep,
                  predictionIfWakesNow: state.predictionIfWakesNow,
                  onTransitionAccept: (naps) => cubit.applyTransition(naps),
                  onTransitionDismiss: () => cubit.applyTransition(
                    state.prediction?.napsExpected ?? 3,
                  ),
                ),
                const SizedBox(height: 14),
                SleepButton(
                  isAsleep: state.isAsleep,
                  childName: child?.nickname,
                  onPressed: cubit.toggleSleep,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    QuickAction(
                      icon: Icons.local_drink_outlined,
                      label: 'Feed',
                      color: c.clay,
                      onTap: () async {
                        final kind = await showFeedSheet(context);
                        if (kind != null) cubit.logFeed(kind);
                      },
                    ),
                    const SizedBox(width: 10),
                    QuickAction(
                      icon: Icons.baby_changing_station,
                      label: 'Diaper',
                      color: c.sage,
                      onTap: () async {
                        final kind = await showDiaperSheet(context);
                        if (kind != null) cubit.logDiaper(kind);
                      },
                    ),
                    const SizedBox(width: 10),
                    QuickAction(
                      icon: Icons.sticky_note_2_outlined,
                      label: 'Note',
                      color: c.sun,
                      onTap: () async {
                        final note = await showNoteSheet(context);
                        if (note != null) cubit.logNote(note);
                      },
                    ),
                    const SizedBox(width: 10),
                    QuickAction(
                      icon: Icons.dark_mode_outlined,
                      label: 'Night wake',
                      color: c.dusk,
                      onTap: () {
                        cubit.logNightWaking();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Night waking logged')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionLabel(
                  'Today',
                  trailing: _DaySummary(events: state.todayEvents),
                ),
                TimelineList(
                  events: state.todayEvents,
                  caregivers: state.family.caregivers,
                  now: state.now,
                  childName: child?.nickname,
                  onTapEvent: (event) => showEventEditSheet(context, event),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact glanceable recap: naps · day sleep · feeds · diapers.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.events});

  final List<CareEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final naps = events.where((e) => e.isSleep && e.endAt != null).toList();
    final sleepMins = naps.fold<int>(
      0,
      (sum, e) => sum + e.duration!.inMinutes,
    );
    final feeds = events.where((e) => e.type == CareEventType.feed).length;
    final diapers = events.where((e) => e.type == CareEventType.diaper).length;
    final parts = <String>[
      if (naps.isNotEmpty)
        '${naps.length} sleep${naps.length == 1 ? '' : 's'} · ${formatDurationMinutes(sleepMins)}',
      if (feeds > 0) '$feeds feed${feeds == 1 ? '' : 's'}',
      if (diapers > 0) '$diapers diaper${diapers == 1 ? '' : 's'}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0),
    );
  }
}

class _HandoffPill extends StatelessWidget {
  const _HandoffPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: c.ink.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 20, color: c.background),
            const SizedBox(width: 8),
            Text(
              'Handoff to next caregiver',
              style: TextStyle(
                color: c.background,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: c.background),
          ],
        ),
      ),
    );
  }
}

class _PresenceStack extends StatelessWidget {
  const _PresenceStack({required this.caregivers});

  final List caregivers;

  @override
  Widget build(BuildContext context) {
    final visible = caregivers.take(3).toList();
    return SizedBox(
      height: 36,
      width: visible.isEmpty ? 0 : 36.0 + (visible.length - 1) * 22.0,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 22.0,
              child: CaregiverDot(
                caregiver: visible[i],
                size: 36,
                showRing: _activeRecently(visible[i].lastActiveAt),
              ),
            ),
        ],
      ),
    );
  }

  bool _activeRecently(DateTime? lastActiveAt) =>
      lastActiveAt != null &&
      DateTime.now().difference(lastActiveAt) < const Duration(hours: 2);
}
