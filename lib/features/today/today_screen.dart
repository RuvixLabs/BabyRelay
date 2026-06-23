import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/design/relay_widgets.dart';
import '../../core/reviews/review_prompt_sheet.dart';
import '../../core/tutorial/coach_marks.dart';
import '../../core/tutorial/tutorial_service.dart';
import '../../core/util/formats.dart';
import '../../data/family_repository.dart';
import '../../domain/models/care_event.dart';
import '../../domain/services/sleep_summary_service.dart';
import '../children/child_switcher.dart';
import '../timeline/event_edit_sheet.dart';
import 'today_cubit.dart';
import 'widgets/manual_sleep_sheet.dart';
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

class _TodayView extends StatefulWidget {
  const _TodayView();

  @override
  State<_TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<_TodayView> {
  final _sleepButtonKey = GlobalKey(debugLabel: 'coach-sleep-button');
  final _quickActionsKey = GlobalKey(debugLabel: 'coach-quick-actions');
  final _handoffKey = GlobalKey(debugLabel: 'coach-handoff');
  RouteInformationProvider? _routeInformationProvider;
  bool _todayTourQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteInformationProvider = GoRouter.of(
      context,
    ).routeInformationProvider;
    if (_routeInformationProvider == nextRouteInformationProvider) return;
    _routeInformationProvider?.removeListener(_handleRouteChanged);
    _routeInformationProvider = nextRouteInformationProvider
      ..addListener(_handleRouteChanged);
  }

  @override
  void dispose() {
    _routeInformationProvider?.removeListener(_handleRouteChanged);
    super.dispose();
  }

  void _handleRouteChanged() {
    if (!mounted) return;
    _queueTodayTour(context);
  }

  String _greeting(DateTime now) {
    if (now.hour < 5) return 'Late night shift';
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    if (now.hour < 21) return 'Good evening';
    return 'Night shift';
  }

  void _queueTodayTour(BuildContext context) {
    if (_todayTourQueued) return;
    if (!_isTodayTopRoute(context)) return;
    final tutorial = context.read<TutorialService>();
    if (!tutorial.shouldShow(TutorialIds.todayIntro)) return;
    _todayTourQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_isTodayTopRoute(context)) {
        _todayTourQueued = false;
        return;
      }
      if (!tutorial.shouldShow(TutorialIds.todayIntro)) return;
      final analytics = context.read<AnalyticsService>();
      analytics.logEvent('coach_mark_seen', {
        'section': TutorialIds.todayIntro,
      });
      final result = await showCoachMarks(
        context: context,
        steps: [
          CoachMarkStep(
            targetKey: _sleepButtonKey,
            title: 'Start with one tap',
            body:
                'Log sleep live, backdate the start, or add a nap afterward when someone forgot.',
            icon: Icons.nightlight_round,
          ),
          CoachMarkStep(
            targetKey: _quickActionsKey,
            title: 'Log care as it happens',
            body:
                'Feeds, diapers, notes, and night wakes all land in the shared timeline.',
            icon: Icons.bolt_rounded,
          ),
          CoachMarkStep(
            targetKey: _handoffKey,
            title: 'Hand off without guesswork',
            body:
                'When someone takes over, send the day so far in one clean summary.',
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      );
      if (!mounted) return;
      await tutorial.markSeen(TutorialIds.todayIntro);
      analytics.logEvent(
        result == CoachMarkResult.completed
            ? 'coach_mark_completed'
            : 'coach_mark_skipped',
        {'section': TutorialIds.todayIntro},
      );
    });
  }

  bool _isTodayTopRoute(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (Navigator.of(context, rootNavigator: true).canPop()) return false;
    return GoRouter.of(context).routeInformationProvider.value.uri.path ==
        '/today';
  }

  Future<void> _trackAndMaybeAskForReview(
    Future<void> Function() action,
  ) async {
    await action();
    await _maybeAskForReviewAfterTracking();
  }

  Future<void> _maybeAskForReviewAfterTracking() async {
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await maybeShowTrackingReviewPrompt(context);
  }

  Future<void> _showManualSleepEntry(TodayState state, TodayCubit cubit) async {
    final draft = await showManualSleepSheet(
      context,
      now: state.now,
      childName: state.child?.nickname,
    );
    if (draft == null) return;
    await _trackAndMaybeAskForReview(
      () => cubit.logManualSleep(
        startAt: draft.startAt,
        endAt: draft.endAt,
        note: draft.note,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sleep added: ${formatTime(draft.startAt)} – ${formatTime(draft.endAt)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    context.watch<TutorialService>();

    return BlocBuilder<TodayCubit, TodayState>(
      builder: (context, state) {
        _queueTodayTour(context);
        final cubit = context.read<TodayCubit>();
        final child = state.child;
        final caregivers = state.family.activeCaregivers;
        final you = state.family.currentCaregiver;
        final sleepSummary = child == null
            ? null
            : const SleepSummaryService().summarizeDay(
                child: child,
                events: state.family.eventsForChild(child.id),
                now: state.now,
              );

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
                KeyedSubtree(
                  key: _handoffKey,
                  child: _HandoffPill(
                    onTap: () {
                      context.read<AnalyticsService>().logEvent(
                        'handoff_opened',
                      );
                      context.push('/handoff');
                    },
                  ),
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
                KeyedSubtree(
                  key: _sleepButtonKey,
                  child: SleepButton(
                    isAsleep: state.isAsleep,
                    childName: child?.nickname,
                    onPressed: () =>
                        _trackAndMaybeAskForReview(cubit.toggleSleep),
                  ),
                ),
                const SizedBox(height: 10),
                _SleepCorrectionRow(
                  isAsleep: state.isAsleep,
                  ongoingSleep: state.ongoingSleep,
                  onStartedEarlier: () => _trackAndMaybeAskForReview(
                    () => cubit.startSleepAt(
                      state.now.subtract(const Duration(minutes: 10)),
                    ),
                  ),
                  onWokeEarlier: () => _trackAndMaybeAskForReview(
                    () => cubit.endSleepAt(
                      state.now.subtract(const Duration(minutes: 10)),
                    ),
                  ),
                  onAdjustOngoing: state.ongoingSleep == null
                      ? null
                      : () => showEventEditSheet(context, state.ongoingSleep!),
                  onAddPastSleep: () => _showManualSleepEntry(state, cubit),
                ),
                const SizedBox(height: 14),
                if (sleepSummary != null) ...[
                  _SleepRhythmCard(summary: sleepSummary),
                  const SizedBox(height: 14),
                ],
                KeyedSubtree(
                  key: _quickActionsKey,
                  child: Row(
                    children: [
                      QuickAction(
                        icon: Icons.local_drink_outlined,
                        label: 'Feed',
                        color: c.clay,
                        onTap: () async {
                          final kind = await showFeedSheet(context);
                          if (kind != null) {
                            await _trackAndMaybeAskForReview(
                              () => cubit.logFeed(kind),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.baby_changing_station,
                        label: 'Diaper',
                        color: c.sage,
                        onTap: () async {
                          final kind = await showDiaperSheet(context);
                          if (kind != null) {
                            await _trackAndMaybeAskForReview(
                              () => cubit.logDiaper(kind),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Note',
                        color: c.sun,
                        onTap: () async {
                          final note = await showNoteSheet(context);
                          if (note != null) {
                            await _trackAndMaybeAskForReview(
                              () => cubit.logNote(note),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.dark_mode_outlined,
                        label: 'Night wake',
                        color: c.dusk,
                        onTap: () async {
                          await cubit.logNightWaking();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Night waking logged'),
                            ),
                          );
                          await _maybeAskForReviewAfterTracking();
                        },
                      ),
                    ],
                  ),
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

class _SleepRhythmCard extends StatelessWidget {
  const _SleepRhythmCard({required this.summary});

  final DailySleepSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return RelayCard(
      padding: const EdgeInsets.all(18),
      color: Color.lerp(c.surface, c.dusk, 0.05)!,
      borderColor: c.dusk.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconSquare(icon: Icons.bedtime_rounded, color: c.dusk, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text('Sleep today', style: text.titleMedium)),
              RelayChip(summary.primaryLabel, color: c.dusk),
            ],
          ),
          const SizedBox(height: 8),
          Text(summary.reassurance, style: text.bodyMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 18,
            width: double.infinity,
            child: CustomPaint(
              painter: _SleepRibbonPainter(
                summary: summary,
                trackColor: c.outline.withValues(alpha: 0.45),
                dayColor: c.dusk,
                nightColor: c.nightHigh,
                ongoingColor: c.sage,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SleepStat(
                label: 'Naps',
                value: '${summary.napCount}',
                color: c.dusk,
              ),
              _SleepStat(
                label: 'Day sleep',
                value: formatDurationMinutes(summary.daySleepMinutes),
                color: c.clay,
              ),
              _SleepStat(
                label: 'Night',
                value: formatDurationMinutes(summary.nightSleepMinutes),
                color: c.nightHigh,
              ),
            ],
          ),
          if (summary.averageNapMinutes > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Average nap ${formatDurationMinutes(summary.averageNapMinutes)} · longest sleep ${formatDurationMinutes(summary.longestSleepMinutes)}.',
              style: text.bodySmall?.copyWith(color: c.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepCorrectionRow extends StatelessWidget {
  const _SleepCorrectionRow({
    required this.isAsleep,
    required this.onStartedEarlier,
    required this.onWokeEarlier,
    required this.onAddPastSleep,
    this.ongoingSleep,
    this.onAdjustOngoing,
  });

  final bool isAsleep;
  final CareEvent? ongoingSleep;
  final VoidCallback onStartedEarlier;
  final VoidCallback onWokeEarlier;
  final VoidCallback onAddPastSleep;
  final VoidCallback? onAdjustOngoing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isAsleep) ...[
          _CorrectionChip(
            icon: Icons.history_toggle_off_rounded,
            label: 'Woke 10 min ago',
            onTap: onWokeEarlier,
          ),
          if (ongoingSleep != null && onAdjustOngoing != null)
            _CorrectionChip(
              icon: Icons.tune_rounded,
              label: 'Adjust start',
              onTap: onAdjustOngoing!,
            ),
        ] else ...[
          _CorrectionChip(
            icon: Icons.replay_10_rounded,
            label: 'Started 10 min ago',
            onTap: onStartedEarlier,
          ),
        ],
        _CorrectionChip(
          icon: Icons.add_alarm_rounded,
          label: 'Add past sleep',
          onTap: onAddPastSleep,
        ),
      ],
    );
  }
}

class _CorrectionChip extends StatelessWidget {
  const _CorrectionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    return PressableScale(
      scale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: c.dusk),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStat extends StatelessWidget {
  const _SleepStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: text.titleMedium?.copyWith(
                color: Color.lerp(color, c.ink, 0.18),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: text.labelSmall?.copyWith(letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}

class _SleepRibbonPainter extends CustomPainter {
  const _SleepRibbonPainter({
    required this.summary,
    required this.trackColor,
    required this.dayColor,
    required this.nightColor,
    required this.ongoingColor,
  });

  final DailySleepSummary summary;
  final Color trackColor;
  final Color dayColor;
  final Color nightColor;
  final Color ongoingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = trackColor);
    if (summary.sleepEvents.isEmpty) return;

    final dayMinutes = summary.dayEnd.difference(summary.dayStart).inMinutes;
    for (final sleep in summary.sleepEvents) {
      final rawEnd = sleep.endAt ?? summary.now;
      final start = sleep.startAt.isBefore(summary.dayStart)
          ? summary.dayStart
          : sleep.startAt;
      final end = rawEnd.isAfter(summary.dayEnd) ? summary.dayEnd : rawEnd;
      if (!end.isAfter(start)) continue;
      final left =
          start.difference(summary.dayStart).inMinutes /
          dayMinutes *
          size.width;
      final right =
          end.difference(summary.dayStart).inMinutes / dayMinutes * size.width;
      final adjustedRight = right.clamp(left + 2, size.width).toDouble();
      final color = sleep.isOngoingSleep
          ? ongoingColor
          : (sleep.startAt.hour >= 6 && sleep.startAt.hour < 19
                ? dayColor
                : nightColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, adjustedRight, size.height),
          radius,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SleepRibbonPainter oldDelegate) =>
      oldDelegate.summary != summary ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.dayColor != dayColor ||
      oldDelegate.nightColor != nightColor ||
      oldDelegate.ongoingColor != ongoingColor;
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
