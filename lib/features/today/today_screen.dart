import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../data/family_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<TodayCubit, TodayState>(
      builder: (context, state) {
        final cubit = context.read<TodayCubit>();
        final baby = state.family.baby;
        final caregivers = state.family.activeCaregivers;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Header: baby identity + presence + handoff entry.
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baby?.nickname ?? 'Baby',
                            style: text.displayMedium,
                          ),
                          if (baby != null)
                            Text(
                              baby.ageLabelAt(state.now),
                              style: text.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    _PresenceStack(caregivers: caregivers),
                  ],
                ),
                const SizedBox(height: 10),
                // Handoff is the product promise — keep it one tap from home.
                _HandoffPill(
                  onTap: () {
                    context.read<AnalyticsService>().logEvent('handoff_opened');
                    context.push('/handoff');
                  },
                ),
                const SizedBox(height: 18),
                NextUpCard(
                  now: state.now,
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
                  'Today\'s timeline',
                  trailing: state.todayEvents.isEmpty
                      ? null
                      : Text(
                          state.todayEvents.length == 1
                              ? '1 entry'
                              : '${state.todayEvents.length} entries',
                          style: text.labelSmall,
                        ),
                ),
                TimelineList(
                  events: state.todayEvents,
                  caregivers: state.family.caregivers,
                  now: state.now,
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

class _HandoffPill extends StatelessWidget {
  const _HandoffPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(100),
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
