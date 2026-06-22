import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../domain/models/baby_profile.dart';
import '../domain/models/care_event.dart';
import '../domain/models/caregiver.dart';
import '../domain/services/invite_service.dart';
import 'local_store.dart';

/// Immutable snapshot of the shared family/care state.
///
/// A family has one care team and any number of children. Every care event
/// is scoped to a child; the UI focuses on [selectedChild] at a time.
class FamilyState {
  /// Version of the persisted/exported JSON shape. The app has never
  /// shipped, so v1 IS the clean multi-child schema — there are no older
  /// shapes to migrate from.
  static const int schemaVersion = 1;

  const FamilyState({
    this.familyId = '',
    this.children = const [],
    this.selectedChildId = '',
    this.caregivers = const [],
    this.events = const [],
    this.currentCaregiverId = '',
    this.inviteCode = '',
    this.familySubscriptionActive = false,
    this.familySubscriptionPlanId = '',
    this.familySubscriptionOwnerId = '',
    this.onboarded = false,
  });

  /// Firestore family document id when production sync is configured.
  final String familyId;
  final List<BabyProfile> children;
  final String selectedChildId;
  final List<Caregiver> caregivers;
  final List<CareEvent> events;
  final String currentCaregiverId;
  final String inviteCode;
  final bool familySubscriptionActive;
  final String familySubscriptionPlanId;
  final String familySubscriptionOwnerId;
  final bool onboarded;

  BabyProfile? get selectedChild {
    for (final child in children) {
      if (child.id == selectedChildId) return child;
    }
    return children.isEmpty ? null : children.first;
  }

  BabyProfile? childById(String id) {
    for (final child in children) {
      if (child.id == id) return child;
    }
    return null;
  }

  List<Caregiver> get activeCaregivers =>
      caregivers.where((c) => c.isActive).toList();

  Caregiver? get currentCaregiver {
    for (final c in caregivers) {
      if (c.id == currentCaregiverId) return c;
    }
    return null;
  }

  /// All events for one child, in start order.
  List<CareEvent> eventsForChild(String childId) =>
      events.where((e) => e.childId == childId).toList();

  CareEvent? ongoingSleepFor(String childId) {
    for (final e in events.reversed) {
      if (e.childId == childId && e.isOngoingSleep) return e;
    }
    return null;
  }

  /// Ongoing sleep for the selected child.
  CareEvent? get ongoingSleep {
    final child = selectedChild;
    if (child == null) return null;
    return ongoingSleepFor(child.id);
  }

  bool get isAsleep => ongoingSleep != null;
  bool isChildAsleep(String childId) => ongoingSleepFor(childId) != null;

  /// Selected child's events on the given calendar day, newest first.
  List<CareEvent> eventsOn(DateTime day, {String? childId}) {
    final id = childId ?? selectedChild?.id;
    if (id == null) return const [];
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final list =
        events
            .where(
              (e) =>
                  e.childId == id &&
                  (!e.startAt.isBefore(start) && e.startAt.isBefore(end) ||
                      (e.endAt != null &&
                          !e.endAt!.isBefore(start) &&
                          e.endAt!.isBefore(end))),
            )
            .toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return list;
  }

  FamilyState copyWith({
    String? familyId,
    List<BabyProfile>? children,
    String? selectedChildId,
    List<Caregiver>? caregivers,
    List<CareEvent>? events,
    String? currentCaregiverId,
    String? inviteCode,
    bool? familySubscriptionActive,
    String? familySubscriptionPlanId,
    String? familySubscriptionOwnerId,
    bool? onboarded,
  }) {
    return FamilyState(
      familyId: familyId ?? this.familyId,
      children: children ?? this.children,
      selectedChildId: selectedChildId ?? this.selectedChildId,
      caregivers: caregivers ?? this.caregivers,
      events: events ?? this.events,
      currentCaregiverId: currentCaregiverId ?? this.currentCaregiverId,
      inviteCode: inviteCode ?? this.inviteCode,
      familySubscriptionActive:
          familySubscriptionActive ?? this.familySubscriptionActive,
      familySubscriptionPlanId:
          familySubscriptionPlanId ?? this.familySubscriptionPlanId,
      familySubscriptionOwnerId:
          familySubscriptionOwnerId ?? this.familySubscriptionOwnerId,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'familyId': familyId,
    'children': children.map((c) => c.toJson()).toList(),
    'selectedChildId': selectedChildId,
    'caregivers': caregivers.map((c) => c.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'currentCaregiverId': currentCaregiverId,
    'inviteCode': inviteCode,
    'familySubscriptionActive': familySubscriptionActive,
    'familySubscriptionPlanId': familySubscriptionPlanId,
    'familySubscriptionOwnerId': familySubscriptionOwnerId,
    'onboarded': onboarded,
  };

  factory FamilyState.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      // Written by a different app schema than this clean pre-launch build.
      throw FormatException('Unsupported family schema version $version');
    }
    final rawChildren = json['children'];
    final rawCaregivers = json['caregivers'];
    final rawEvents = json['events'];
    if (rawChildren is! List || rawCaregivers is! List || rawEvents is! List) {
      throw const FormatException('Family payload missing required lists');
    }

    final children = rawChildren
        .map((c) => BabyProfile.fromJson(c as Map<String, dynamic>))
        .toList();
    final events = rawEvents
        .map((e) => CareEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    var selectedChildId = json['selectedChildId'] as String? ?? '';
    if (children.isNotEmpty && !children.any((c) => c.id == selectedChildId)) {
      selectedChildId = children.first.id;
    }

    return FamilyState(
      familyId: json['familyId'] as String? ?? '',
      children: children,
      selectedChildId: selectedChildId,
      caregivers: rawCaregivers
          .map((c) => Caregiver.fromJson(c as Map<String, dynamic>))
          .toList(),
      events: events,
      currentCaregiverId: json['currentCaregiverId'] as String? ?? '',
      inviteCode: json['inviteCode'] as String? ?? '',
      familySubscriptionActive:
          json['familySubscriptionActive'] as bool? ?? false,
      familySubscriptionPlanId:
          json['familySubscriptionPlanId'] as String? ?? '',
      familySubscriptionOwnerId:
          json['familySubscriptionOwnerId'] as String? ?? '',
      onboarded: json['onboarded'] as bool? ?? false,
    );
  }
}

/// Production sync adapter for the local-first family repository.
///
/// The UI talks to [FamilyRepository] only. Firebase plugs in through this
/// surface so local tests, previews, and App Review-safe fallback behavior keep
/// working when provider keys are absent.
abstract class FamilySyncAdapter {
  String get userId;

  String newFamilyId();

  Stream<FamilyState> watchFamily(String familyId);

  Future<void> saveFamily(FamilyState state, {String? previousInviteCode});

  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  });

  Future<void> deleteFamily(FamilyState state);

  Future<void> dispose() async {}
}

/// Local-first repository for the shared family state.
///
/// This is the seam where Firestore lands later: same mutation API, but
/// writes go to `families/{familyId}/...` and the change stream comes from
/// snapshots instead of [notifyListeners].
class FamilyRepository extends ChangeNotifier {
  FamilyRepository(this._store, {FamilySyncAdapter? sync}) : _sync = sync;

  static const int freeCaregiverLimit = 2;
  static const _storageKey = 'babyrelay.family.v1';
  final LocalStore _store;
  FamilySyncAdapter? _sync;
  StreamSubscription<FamilyState>? _remoteSubscription;
  String? _watchedFamilyId;
  bool _applyingRemote = false;

  FamilyState _state = const FamilyState();
  FamilyState get state => _state;
  bool get syncConfigured => _sync != null;
  String? get syncUserId => _sync?.userId;

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

  Future<void> attachSync(FamilySyncAdapter sync) async {
    _sync = sync;
    final current = _state.currentCaregiver;
    if (_state.onboarded &&
        current?.isOwner == true &&
        current!.id != sync.userId) {
      await _commit(_rekeyCaregiver(_state, from: current.id, to: sync.userId));
      return;
    }
    if (_state.onboarded && _state.familyId.isNotEmpty) {
      await sync.saveFamily(_state);
      _watchFamily(_state.familyId);
    }
  }

  FamilyState _rekeyCaregiver(
    FamilyState state, {
    required String from,
    required String to,
  }) {
    if (from == to) return state;
    return state.copyWith(
      caregivers: state.caregivers
          .map((c) => c.id == from ? c.copyWith(id: to) : c)
          .toList(),
      currentCaregiverId: state.currentCaregiverId == from
          ? to
          : state.currentCaregiverId,
      events: state.events
          .map(
            (event) => event.copyWith(
              loggedById: event.loggedById == from ? to : event.loggedById,
              editedByIds: event.editedByIds
                  .map((id) => id == from ? to : id)
                  .toSet()
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  void _watchFamily(String familyId) {
    final sync = _sync;
    if (sync == null || familyId.isEmpty || _watchedFamilyId == familyId) {
      return;
    }
    unawaited(_remoteSubscription?.cancel());
    _watchedFamilyId = familyId;
    _remoteSubscription = sync.watchFamily(familyId).listen((remote) async {
      if (_applyingRemote) return;
      _applyingRemote = true;
      try {
        final merged = _mergeRemoteFamilyState(remote);
        _state = merged;
        notifyListeners();
        await _store.write(_storageKey, jsonEncode(merged.toJson()));
      } finally {
        _applyingRemote = false;
      }
    });
  }

  FamilyState _mergeRemoteFamilyState(FamilyState remote) {
    var merged = remote;

    final localCaregiverId = _state.currentCaregiverId;
    if (localCaregiverId.isNotEmpty &&
        remote.caregivers.any((c) => c.id == localCaregiverId && c.isActive)) {
      merged = merged.copyWith(currentCaregiverId: localCaregiverId);
    }

    final localSelectedChildId = _state.selectedChildId;
    if (localSelectedChildId.isNotEmpty &&
        remote.children.any((c) => c.id == localSelectedChildId)) {
      merged = merged.copyWith(selectedChildId: localSelectedChildId);
    }

    return merged;
  }

  Future<void> _commit(FamilyState next) async {
    final previousInviteCode = _state.inviteCode;
    final sync = _sync;
    var committed = next;
    if (committed.onboarded && committed.familyId.isEmpty) {
      committed = committed.copyWith(
        familyId: sync?.newFamilyId() ?? _newId('f'),
      );
    }
    _state = committed;
    notifyListeners();
    await _store.write(_storageKey, jsonEncode(committed.toJson()));
    if (!_applyingRemote && sync != null && committed.familyId.isNotEmpty) {
      await sync.saveFamily(committed, previousInviteCode: previousInviteCode);
      _watchFamily(committed.familyId);
    }
  }

  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  String get _selectedChildIdOrEmpty => _state.selectedChild?.id ?? '';

  // ---------------------------------------------------------------------------
  // Onboarding / children

  Future<void> completeOnboarding({
    required BabyProfile firstChild,
    required String primaryCaregiverName,
  }) async {
    final ownerId = _sync?.userId ?? _newId('c');
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
    final child = firstChild.id.isEmpty
        ? _withNewId(firstChild, colorIndex: 0)
        : firstChild;
    await _commit(
      FamilyState(
        children: [child],
        selectedChildId: child.id,
        caregivers: [owner],
        events: const [],
        currentCaregiverId: ownerId,
        inviteCode: InviteService.generateCode(),
        onboarded: true,
      ),
    );
  }

  BabyProfile _withNewId(BabyProfile child, {required int colorIndex}) {
    return BabyProfile(
      id: _newId('b'),
      nickname: child.nickname,
      dob: child.dob,
      wakeTimeMinutes: child.wakeTimeMinutes,
      bedtimeMinutes: child.bedtimeMinutes,
      napsPerDayEstimate: child.napsPerDayEstimate,
      colorIndex: colorIndex,
      scheduleOverrideNaps: child.scheduleOverrideNaps,
    );
  }

  /// Adds another child to the family and selects them.
  Future<BabyProfile> addChild(BabyProfile child) async {
    final withId = child.id.isEmpty
        ? _withNewId(child, colorIndex: _state.children.length % 6)
        : child;
    await _commit(
      _state.copyWith(
        children: [..._state.children, withId],
        selectedChildId: withId.id,
      ),
    );
    return withId;
  }

  Future<void> updateChild(BabyProfile child) async {
    await _commit(
      _state.copyWith(
        children: _state.children
            .map((c) => c.id == child.id ? child : c)
            .toList(),
      ),
    );
  }

  /// Removes a child and every event logged for them.
  Future<void> removeChild(String childId) async {
    final remaining = _state.children.where((c) => c.id != childId).toList();
    await _commit(
      _state.copyWith(
        children: remaining,
        selectedChildId: _state.selectedChildId == childId
            ? (remaining.isEmpty ? '' : remaining.first.id)
            : _state.selectedChildId,
        events: _state.events.where((e) => e.childId != childId).toList(),
      ),
    );
  }

  Future<void> selectChild(String childId) async {
    if (_state.selectedChildId == childId ||
        !_state.children.any((c) => c.id == childId)) {
      return;
    }
    await _commit(_state.copyWith(selectedChildId: childId));
  }

  Future<void> applyScheduleOverride(int naps, {String? childId}) async {
    final child = childId == null
        ? _state.selectedChild
        : _state.childById(childId);
    if (child == null) return;
    await updateChild(child.copyWith(scheduleOverrideNaps: naps));
  }

  // ---------------------------------------------------------------------------
  // Care events (scoped to a child; defaults to the selected one)

  Future<CareEvent?> startSleep({DateTime? at, String? childId}) async {
    final id = childId ?? _selectedChildIdOrEmpty;
    if (id.isEmpty || _state.isChildAsleep(id)) return null;
    final event = CareEvent(
      id: _newId('e'),
      childId: id,
      type: CareEventType.sleep,
      startAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent?> endSleep({DateTime? at, String? childId}) async {
    final id = childId ?? _selectedChildIdOrEmpty;
    final ongoing = _state.ongoingSleepFor(id);
    if (ongoing == null) return null;
    var end = at ?? DateTime.now();
    if (end.isBefore(ongoing.startAt)) end = ongoing.startAt;
    final updated = ongoing.copyWith(endAt: end);
    await _replaceEvent(updated);
    return updated;
  }

  Future<CareEvent> logFeed(
    FeedKind kind, {
    String? note,
    DateTime? at,
    String? childId,
  }) async {
    final event = CareEvent(
      id: _newId('e'),
      childId: childId ?? _selectedChildIdOrEmpty,
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

  Future<CareEvent> logDiaper(
    DiaperKind kind, {
    DateTime? at,
    String? childId,
  }) async {
    final event = CareEvent(
      id: _newId('e'),
      childId: childId ?? _selectedChildIdOrEmpty,
      type: CareEventType.diaper,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      diaperKind: kind,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent> logNote(
    String note, {
    DateTime? at,
    String? childId,
  }) async {
    final event = CareEvent(
      id: _newId('e'),
      childId: childId ?? _selectedChildIdOrEmpty,
      type: CareEventType.note,
      startAt: at ?? DateTime.now(),
      endAt: at ?? DateTime.now(),
      loggedById: _state.currentCaregiverId,
      note: note,
    );
    await _commitEvent(event);
    return event;
  }

  Future<CareEvent> logNightWaking({
    String? note,
    DateTime? at,
    String? childId,
  }) async {
    final event = CareEvent(
      id: _newId('e'),
      childId: childId ?? _selectedChildIdOrEmpty,
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

  /// Sleep events for the same child (other than [event]) whose time range
  /// overlaps it.
  List<CareEvent> overlappingSleeps(CareEvent event) {
    if (!event.isSleep) return const [];
    final start = event.startAt;
    final end = event.endAt ?? DateTime.now();
    return _state.events.where((other) {
      if (other.id == event.id ||
          !other.isSleep ||
          other.childId != event.childId) {
        return false;
      }
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
      childId: first.childId,
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
  /// first, for one child. Days with no logs are skipped (no signal, not
  /// zero naps).
  List<int> recentNapCounts({int days = 7, DateTime? now, String? childId}) {
    final id = childId ?? _selectedChildIdOrEmpty;
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
            e.childId == id &&
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
    await _commit(_state.copyWith(inviteCode: InviteService.generateCode()));
  }

  Future<void> setFamilySubscriptionStatus({
    required bool active,
    String planId = '',
  }) async {
    await _commit(
      _state.copyWith(
        familySubscriptionActive: active,
        familySubscriptionPlanId: active ? planId : '',
        familySubscriptionOwnerId: active ? _state.currentCaregiverId : '',
      ),
    );
  }

  Future<void> joinFamilyByInviteCode({
    required String code,
    required String caregiverName,
    required bool allowOverFreeCaregiverLimit,
  }) async {
    final sync = _sync;
    if (sync == null) {
      throw StateError('Family sync is not configured for this build.');
    }
    final now = DateTime.now();
    final caregiver = Caregiver(
      id: sync.userId,
      name: caregiverName.trim().isEmpty ? 'Caregiver' : caregiverName.trim(),
      role: CaregiverRole.caregiver,
      colorIndex: _state.caregivers.length % 6,
      joinedAt: now,
      lastActiveAt: now,
    );
    final joined = await sync.joinFamilyByInviteCode(
      code: code,
      caregiver: caregiver,
      freeCaregiverLimit: freeCaregiverLimit,
      allowOverFreeCaregiverLimit: allowOverFreeCaregiverLimit,
    );
    await _commit(
      joined.copyWith(
        currentCaregiverId: caregiver.id,
        onboarded: true,
        selectedChildId:
            joined.selectedChildId.isEmpty && joined.children.isNotEmpty
            ? joined.children.first.id
            : joined.selectedChildId,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Privacy / data control

  /// Full data export, wrapped in an envelope so a future import (or a
  /// support inspection) knows exactly which app and schema produced it.
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'app': 'BabyRelay',
    'appVersion': AppConfig.appVersion,
    'schemaVersion': FamilyState.schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'family': _state.toJson(),
  });

  Future<void> deleteAllData() async {
    final sync = _sync;
    final stateToDelete = _state;
    _state = const FamilyState();
    notifyListeners();
    await _store.delete(_storageKey);
    if (sync != null && stateToDelete.currentCaregiver?.isOwner == true) {
      await sync.deleteFamily(stateToDelete);
    }
  }

  /// Seeds a believable sample day so the app can be previewed without
  /// manually logging a full day first. Also adds a sibling so the
  /// multi-child experience can be exercised immediately.
  Future<void> loadSampleDay() async {
    if (!_state.onboarded || _state.selectedChild == null) return;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final me = _state.currentCaregiverId;
    final childId = _state.selectedChild!.id;

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

    // A sibling makes the child switcher and event isolation easy to exercise.
    var children = _state.children;
    var siblingId = children.where((c) => c.id != childId).firstOrNull?.id;
    if (siblingId == null) {
      final sibling = BabyProfile(
        id: _newId('b'),
        nickname: 'Theo',
        dob: day.subtract(const Duration(days: 480)),
        wakeTimeMinutes: 6 * 60 + 45,
        bedtimeMinutes: 19 * 60 + 30,
        napsPerDayEstimate: 1,
        colorIndex: children.length % 6,
      );
      children = [...children, sibling];
      siblingId = sibling.id;
    }

    DateTime at(int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    CareEvent ev(
      String child,
      CareEventType type,
      DateTime start, {
      DateTime? end,
      String? by,
      FeedKind? feed,
      DiaperKind? diaper,
      String? note,
    }) => CareEvent(
      id: _newId('e'),
      childId: child,
      type: type,
      startAt: start,
      endAt: end ?? (type == CareEventType.sleep ? end : start),
      loggedById: by ?? me,
      feedKind: feed,
      diaperKind: diaper,
      note: note,
    );

    final events = <CareEvent>[
      ev(childId, CareEventType.nightWaking, at(3, 10)),
      ev(childId, CareEventType.feed, at(7, 5), feed: FeedKind.bottle),
      ev(childId, CareEventType.diaper, at(7, 20), diaper: DiaperKind.wet),
      ev(
        childId,
        CareEventType.sleep,
        at(9, 0),
        end: at(10, 10),
        by: partnerId,
      ),
      ev(
        childId,
        CareEventType.feed,
        at(10, 30),
        by: partnerId,
        feed: FeedKind.nursing,
      ),
      ev(
        childId,
        CareEventType.note,
        at(10, 40),
        by: partnerId,
        note: 'Bottle finished before nap, a little fussy after.',
      ),
      ev(childId, CareEventType.diaper, at(12, 45), diaper: DiaperKind.both),
      ev(childId, CareEventType.sleep, at(13, 5), end: at(13, 45)),
      // Sibling's lighter day, so switching children visibly changes Today.
      ev(
        siblingId,
        CareEventType.feed,
        at(7, 30),
        feed: FeedKind.solids,
        by: partnerId,
      ),
      ev(siblingId, CareEventType.sleep, at(12, 30), end: at(14, 0)),
      ev(
        siblingId,
        CareEventType.note,
        at(14, 5),
        note: 'Big lunch, happy after the nap.',
      ),
    ];

    final all = [..._state.events, ...events]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    await _commit(
      _state.copyWith(events: all, caregivers: caregivers, children: children),
    );
  }

  @override
  void dispose() {
    unawaited(_remoteSubscription?.cancel());
    unawaited(_sync?.dispose());
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
