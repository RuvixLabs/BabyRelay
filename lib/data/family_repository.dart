import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/models/baby_profile.dart';
import '../domain/models/care_event.dart';
import '../domain/models/caregiver.dart';
import 'local_store.dart';

/// Immutable snapshot of the shared family/care state.
class FamilyState {
  const FamilyState({
    this.baby,
    this.caregivers = const [],
    this.events = const [],
    this.currentCaregiverId = '',
    this.inviteCode = '',
    this.onboarded = false,
  });

  final BabyProfile? baby;
  final List<Caregiver> caregivers;
  final List<CareEvent> events;
  final String currentCaregiverId;
  final String inviteCode;
  final bool onboarded;

  List<Caregiver> get activeCaregivers =>
      caregivers.where((c) => c.isActive).toList();

  Caregiver? get currentCaregiver {
    for (final c in caregivers) {
      if (c.id == currentCaregiverId) return c;
    }
    return null;
  }

  CareEvent? get ongoingSleep {
    for (final e in events.reversed) {
      if (e.isOngoingSleep) return e;
    }
    return null;
  }

  bool get isAsleep => ongoingSleep != null;

  /// Events that belong to the given calendar day, newest first.
  List<CareEvent> eventsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final list =
        events
            .where(
              (e) =>
                  !e.startAt.isBefore(start) && e.startAt.isBefore(end) ||
                  (e.endAt != null &&
                      !e.endAt!.isBefore(start) &&
                      e.endAt!.isBefore(end)),
            )
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return list;
  }

  FamilyState copyWith({
    BabyProfile? baby,
    List<Caregiver>? caregivers,
    List<CareEvent>? events,
    String? currentCaregiverId,
    String? inviteCode,
    bool? onboarded,
  }) {
    return FamilyState(
      baby: baby ?? this.baby,
      caregivers: caregivers ?? this.caregivers,
      events: events ?? this.events,
      currentCaregiverId: currentCaregiverId ?? this.currentCaregiverId,
      inviteCode: inviteCode ?? this.inviteCode,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'baby': baby?.toJson(),
    'caregivers': caregivers.map((c) => c.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'currentCaregiverId': currentCaregiverId,
    'inviteCode': inviteCode,
    'onboarded': onboarded,
  };

  factory FamilyState.fromJson(Map<String, dynamic> json) => FamilyState(
    baby: json['baby'] == null
        ? null
        : BabyProfile.fromJson(json['baby'] as Map<String, dynamic>),
    caregivers: (json['caregivers'] as List<dynamic>? ?? [])
        .map((c) => Caregiver.fromJson(c as Map<String, dynamic>))
        .toList(),
    events: (json['events'] as List<dynamic>? ?? [])
        .map((e) => CareEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    currentCaregiverId: json['currentCaregiverId'] as String? ?? '',
    inviteCode: json['inviteCode'] as String? ?? '',
    onboarded: json['onboarded'] as bool? ?? false,
  );
}

/// Local demo repository for the shared family state.
///
/// This is the seam where Firestore lands later: same mutation API, but
/// writes go to `families/{familyId}/...` and the change stream comes from
/// snapshots instead of [notifyListeners].
class FamilyRepository extends ChangeNotifier {
  FamilyRepository(this._store);

  static const _storageKey = 'babyrelay.family.v1';
  final LocalStore _store;

  FamilyState _state = const FamilyState();
  FamilyState get state => _state;

  int _idCounter = 0;

  Future<void> load() async {
    final raw = await _store.read(_storageKey);
    if (raw == null) return;
    try {
      _state = FamilyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      // Corrupt local data should never brick the app; start fresh.
      _state = const FamilyState();
    }
  }

  Future<void> _commit(FamilyState next) async {
    _state = next;
    notifyListeners();
    await _store.write(_storageKey, jsonEncode(next.toJson()));
  }

  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  static String generateInviteCode([Random? random]) {
    // No ambiguous characters (0/O, 1/I/L) — caregivers read these out loud.
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = random ?? Random();
    return List.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }

  // ---------------------------------------------------------------------------
  // Onboarding / profile

  Future<void> completeOnboarding({
    required BabyProfile baby,
    required String primaryCaregiverName,
  }) async {
    final ownerId = _newId('c');
    final owner = Caregiver(
      id: ownerId,
      name: primaryCaregiverName.trim().isEmpty
          ? 'You'
          : primaryCaregiverName.trim(),
      role: CaregiverRole.owner,
      colorIndex: 0,
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    await _commit(
      FamilyState(
        baby: baby,
        caregivers: [owner],
        events: const [],
        currentCaregiverId: ownerId,
        inviteCode: generateInviteCode(),
        onboarded: true,
      ),
    );
  }

  Future<void> updateBaby(BabyProfile baby) async {
    await _commit(_state.copyWith(baby: baby));
  }

  Future<void> applyScheduleOverride(int naps) async {
    final baby = _state.baby;
    if (baby == null) return;
    await _commit(
      _state.copyWith(baby: baby.copyWith(scheduleOverrideNaps: naps)),
    );
  }

  // ---------------------------------------------------------------------------
  // Care events

  Future<CareEvent?> startSleep({DateTime? at}) async {
    if (_state.isAsleep) return null;
    final event = CareEvent(
      id: _newId('e'),
      type: CareEventType.sleep,
      startAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent?> endSleep({DateTime? at}) async {
    final ongoing = _state.ongoingSleep;
    if (ongoing == null) return null;
    var end = at ?? DateTime.now();
    if (end.isBefore(ongoing.startAt)) end = ongoing.startAt;
    final updated = ongoing.copyWith(endAt: end);
    await _replaceEvent(updated);
    return updated;
  }

  Future<CareEvent> logFeed(FeedKind kind, {String? note, DateTime? at}) async {
    final event = CareEvent(
      id: _newId('e'),
      type: CareEventType.feed,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      feedKind: kind,
      note: note,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent> logDiaper(DiaperKind kind, {DateTime? at}) async {
    final event = CareEvent(
      id: _newId('e'),
      type: CareEventType.diaper,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      diaperKind: kind,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent> logNote(String note, {DateTime? at}) async {
    final event = CareEvent(
      id: _newId('e'),
      type: CareEventType.note,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      note: note,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent> logNightWaking({String? note, DateTime? at}) async {
    final event = CareEvent(
      id: _newId('e'),
      type: CareEventType.nightWaking,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      note: note,
    );
    await _commitEvent(event);
    return event;
  }

  Future<void> updateEvent(CareEvent updated) async {
    final edited = updated.editedByIds.contains(_state.currentCaregiverId)
        ? updated.editedByIds
        : [...updated.editedByIds, _state.currentCaregiverId];
    await _replaceEvent(updated.copyWith(editedByIds: edited));
  }

  Future<void> deleteEvent(String eventId) async {
    await _commit(
      _state.copyWith(
        events: _state.events.where((e) => e.id != eventId).toList(),
      ),
    );
  }

  /// Sleep events (other than [event]) whose time range overlaps it.
  List<CareEvent> overlappingSleeps(CareEvent event) {
    if (!event.isSleep) return const [];
    final start = event.startAt;
    final end = event.endAt ?? DateTime.now();
    return _state.events.where((other) {
      if (other.id == event.id || !other.isSleep) return false;
      final oStart = other.startAt;
      final oEnd = other.endAt ?? DateTime.now();
      return start.isBefore(oEnd) && oStart.isBefore(end);
    }).toList();
  }

  /// Merges two overlapping sleep events into one span. Keeps the earlier
  /// logger's attribution and records the merger as an editor.
  Future<CareEvent> mergeSleepEvents(CareEvent a, CareEvent b) async {
    final first = a.startAt.isBefore(b.startAt) ? a : b;
    final aEnd = a.endAt ?? DateTime.now();
    final bEnd = b.endAt ?? DateTime.now();
    final keepOpen = a.isOngoingSleep || b.isOngoingSleep;
    final mergedNote = [
      a.note,
      b.note,
    ].where((n) => (n ?? '').trim().isNotEmpty).join(' · ');
    final merged = CareEvent(
      id: first.id,
      type: CareEventType.sleep,
      startAt: first.startAt,
      endAt: keepOpen ? null : (aEnd.isAfter(bEnd) ? aEnd : bEnd),
      loggedById: first.loggedById,
      editedByIds: {
        ...a.editedByIds,
        ...b.editedByIds,
        _state.currentCaregiverId,
      }.toList(),
      note: mergedNote.isEmpty ? null : mergedNote,
      merged: true,
    );
    final remaining =
        _state.events.where((e) => e.id != a.id && e.id != b.id).toList()
          ..add(merged)
          ..sort((x, y) => x.startAt.compareTo(y.startAt));
    await _commit(_state.copyWith(events: remaining));
    return merged;
  }

  /// Completed-nap counts per day for the [days] days before today, oldest
  /// first. Days with no logs are skipped (no signal, not zero naps).
  List<int> recentNapCounts({int days = 7, DateTime? now}) {
    final today = now ?? DateTime.now();
    final counts = <int>[];
    for (var i = days; i >= 1; i--) {
      final day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));
      final daysEvents = _state.events.where(
        (e) =>
            e.isSleep &&
            e.endAt != null &&
            !e.startAt.isBefore(day) &&
            e.startAt.isBefore(dayEnd),
      );
      final naps = daysEvents.where((e) => _isDaySleep(e)).length;
      if (daysEvents.isNotEmpty) counts.add(naps);
    }
    return counts;
  }

  bool _isDaySleep(CareEvent e) => e.startAt.hour >= 6 && e.startAt.hour < 19;

  Future<void> _commitEvent(CareEvent event) async {
    final events = [..._state.events, event]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _commit(
      _state.copyWith(events: events, caregivers: _touchCurrentCaregiver()),
    );
  }

  Future<void> _replaceEvent(CareEvent updated) async {
    final events =
        _state.events.map((e) => e.id == updated.id ? updated : e).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _commit(
      _state.copyWith(events: events, caregivers: _touchCurrentCaregiver()),
    );
  }

  List<Caregiver> _touchCurrentCaregiver() => _state.caregivers
      .map(
        (c) => c.id == _state.currentCaregiverId
            ? c.copyWith(lastActiveAt: DateTime.now())
            : c,
      )
      .toList();

  // ---------------------------------------------------------------------------
  // Care team

  Future<Caregiver> addCaregiver(
    String name, {
    CaregiverRole role = CaregiverRole.caregiver,
  }) async {
    final caregiver = Caregiver(
      id: _newId('c'),
      name: name.trim(),
      role: role,
      colorIndex: _state.caregivers.length % 6,
      joinedAt: DateTime.now(),
    );
    await _commit(
      _state.copyWith(caregivers: [..._state.caregivers, caregiver]),
    );
    return caregiver;
  }

  Future<void> removeCaregiver(String caregiverId) async {
    await _commit(
      _state.copyWith(
        caregivers: _state.caregivers
            .map(
              (c) => c.id == caregiverId
                  ? c.copyWith(removedAt: DateTime.now())
                  : c,
            )
            .toList(),
      ),
    );
  }

  Future<void> regenerateInviteCode() async {
    await _commit(_state.copyWith(inviteCode: generateInviteCode()));
  }

  // ---------------------------------------------------------------------------
  // Privacy / data control

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_state.toJson());

  Future<void> deleteAllData() async {
    _state = const FamilyState();
    notifyListeners();
    await _store.delete(_storageKey);
  }

  /// Seeds a believable demo day so the prototype can be previewed without
  /// manually logging a full day first.
  Future<void> loadSampleDay() async {
    if (!_state.onboarded || _state.baby == null) return;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final me = _state.currentCaregiverId;

    var partnerId = _state.activeCaregivers
        .where((c) => c.id != me)
        .map((c) => c.id)
        .firstOrNull;
    var caregivers = _state.caregivers;
    if (partnerId == null) {
      final partner = Caregiver(
        id: _newId('c'),
        name: 'Sam',
        role: CaregiverRole.caregiver,
        colorIndex: 1,
        joinedAt: day.subtract(const Duration(days: 20)),
        lastActiveAt: now.subtract(const Duration(minutes: 25)),
      );
      caregivers = [...caregivers, partner];
      partnerId = partner.id;
    }

    DateTime at(int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    final events = <CareEvent>[
      CareEvent(
        id: _newId('e'),
        type: CareEventType.nightWaking,
        startAt: at(3, 10),
        endAt: at(3, 10),
        loggedById: me,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.feed,
        startAt: at(7, 5),
        endAt: at(7, 5),
        loggedById: me,
        feedKind: FeedKind.bottle,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.diaper,
        startAt: at(7, 20),
        endAt: at(7, 20),
        loggedById: me,
        diaperKind: DiaperKind.wet,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.sleep,
        startAt: at(9, 0),
        endAt: at(10, 10),
        loggedById: partnerId,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.feed,
        startAt: at(10, 30),
        endAt: at(10, 30),
        loggedById: partnerId,
        feedKind: FeedKind.nursing,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.note,
        startAt: at(10, 40),
        endAt: at(10, 40),
        loggedById: partnerId,
        note: 'Bottle finished before nap, a little fussy after.',
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.diaper,
        startAt: at(12, 45),
        endAt: at(12, 45),
        loggedById: me,
        diaperKind: DiaperKind.both,
      ),
      CareEvent(
        id: _newId('e'),
        type: CareEventType.sleep,
        startAt: at(13, 5),
        endAt: at(13, 45),
        loggedById: me,
      ),
    ];

    final all = [..._state.events, ...events]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _commit(_state.copyWith(events: all, caregivers: caregivers));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
