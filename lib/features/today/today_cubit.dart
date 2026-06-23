import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/family_repository.dart';
import '../../domain/engine/sleep_prediction_engine.dart';
import '../../domain/models/baby_profile.dart';
import '../../domain/models/care_event.dart';
import '../../domain/services/day_context_builder.dart';

class TodayState extends Equatable {
  const TodayState({
    required this.family,
    required this.now,
    this.prediction,
    this.predictionIfWakesNow,
  });

  final FamilyState family;
  final DateTime now;

  /// Next-up prediction while awake.
  final NextUpPrediction? prediction;

  /// While asleep: where the next window would land if the baby woke now.
  final NextUpPrediction? predictionIfWakesNow;

  BabyProfile? get child => family.selectedChild;
  List<BabyProfile> get children => family.children;
  bool get isAsleep => family.isAsleep;
  CareEvent? get ongoingSleep => family.ongoingSleep;
  List<CareEvent> get todayEvents => family.eventsOn(now);

  @override
  List<Object?> get props => [family, now, prediction, predictionIfWakesNow];
}

class TodayCubit extends Cubit<TodayState> {
  TodayCubit(
    this._repo,
    this._analytics, {
    SleepPredictionEngine engine = const SleepPredictionEngine(),
    DayContextBuilder dayBuilder = const DayContextBuilder(),
  }) : _engine = engine,
       _dayBuilder = dayBuilder,
       super(TodayState(family: _repo.state, now: DateTime.now())) {
    _repo.addListener(_recompute);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _recompute());
    _recompute();
  }

  final FamilyRepository _repo;
  final AnalyticsService _analytics;
  final SleepPredictionEngine _engine;
  final DayContextBuilder _dayBuilder;
  Timer? _ticker;

  void _recompute() {
    final family = _repo.state;
    final now = DateTime.now();
    final child = family.selectedChild;
    if (child == null) {
      emit(TodayState(family: family, now: now));
      return;
    }
    final events = family.eventsForChild(child.id);
    final recentCounts = _repo.recentNapCounts(now: now, childId: child.id);
    NextUpPrediction? prediction;
    NextUpPrediction? ifWakesNow;
    if (family.isChildAsleep(child.id)) {
      ifWakesNow = _engine.predict(
        _dayBuilder.build(
          baby: child,
          events: events,
          now: now,
          recentNapCounts: recentCounts,
          assumeAwakeNow: true,
        ),
      );
    } else {
      prediction = _engine.predict(
        _dayBuilder.build(
          baby: child,
          events: events,
          now: now,
          recentNapCounts: recentCounts,
        ),
      );
    }
    emit(
      TodayState(
        family: family,
        now: now,
        prediction: prediction,
        predictionIfWakesNow: ifWakesNow,
      ),
    );
  }

  Future<void> selectChild(String childId) async {
    await _repo.selectChild(childId);
    _analytics.logEvent('child_switched');
  }

  Future<void> toggleSleep() async {
    if (state.isAsleep) {
      await _repo.endSleep();
      _analytics.logEvent('care_event_logged', {'type': 'wake'});
    } else {
      await _repo.startSleep();
      _analytics.logEvent('care_event_logged', {'type': 'sleep'});
    }
  }

  Future<void> startSleepAt(DateTime at) async {
    final event = await _repo.startSleep(at: at);
    if (event != null) {
      _analytics.logEvent('care_event_logged', {'type': 'sleep_backdated'});
    }
  }

  Future<void> endSleepAt(DateTime at) async {
    final ongoing = state.ongoingSleep;
    final safeEndAt = ongoing != null && !at.isAfter(ongoing.startAt)
        ? DateTime.now()
        : at;
    final event = await _repo.endSleep(at: safeEndAt);
    if (event != null) {
      _analytics.logEvent('care_event_logged', {'type': 'wake_backdated'});
    }
  }

  Future<void> logManualSleep({
    required DateTime startAt,
    required DateTime endAt,
    String? note,
  }) async {
    final event = await _repo.logSleep(
      startAt: startAt,
      endAt: endAt,
      note: note,
    );
    if (event != null) {
      _analytics.logEvent('care_event_logged', {'type': 'sleep_manual'});
    }
  }

  Future<void> logFeed(FeedKind kind) async {
    await _repo.logFeed(kind);
    _analytics.logEvent('care_event_logged', {'type': 'feed'});
  }

  Future<void> logDiaper(DiaperKind kind) async {
    await _repo.logDiaper(kind);
    _analytics.logEvent('care_event_logged', {'type': 'diaper'});
  }

  Future<void> logNote(String note) async {
    await _repo.logNote(note);
    _analytics.logEvent('care_event_logged', {'type': 'note'});
  }

  Future<void> logNightWaking() async {
    await _repo.logNightWaking();
    _analytics.logEvent('care_event_logged', {'type': 'night_waking'});
  }

  Future<void> applyTransition(int naps) async {
    await _repo.applyScheduleOverride(naps);
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _repo.removeListener(_recompute);
    return super.close();
  }
}
