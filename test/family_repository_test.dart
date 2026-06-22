import 'dart:async';
import 'dart:convert';

import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:babyrelay/domain/models/caregiver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FamilyRepository repo;
  late InMemoryStore store;

  Future<void> onboard() async {
    await repo.completeOnboarding(
      firstChild: BabyProfile(
        id: '',
        nickname: 'Mae',
        dob: DateTime.now().subtract(const Duration(days: 210)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60,
        napsPerDayEstimate: 3,
      ),
      primaryCaregiverName: 'Sara',
    );
  }

  Future<BabyProfile> addSibling({String name = 'Theo'}) {
    return repo.addChild(
      BabyProfile(
        id: '',
        nickname: name,
        dob: DateTime.now().subtract(const Duration(days: 480)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60 + 30,
        napsPerDayEstimate: 1,
      ),
    );
  }

  setUp(() {
    store = InMemoryStore();
    repo = FamilyRepository(store);
  });

  test(
    'onboarding creates owner, first child, invite code and persists',
    () async {
      await onboard();
      expect(repo.state.onboarded, isTrue);
      expect(repo.state.activeCaregivers, hasLength(1));
      expect(repo.state.currentCaregiver!.isOwner, isTrue);
      expect(repo.state.inviteCode, hasLength(6));
      expect(repo.state.children, hasLength(1));
      expect(repo.state.selectedChild!.id, isNotEmpty);
      expect(repo.state.selectedChildId, repo.state.children.first.id);

      // Round-trips through persistence.
      final reloaded = FamilyRepository(store);
      await reloaded.load();
      expect(reloaded.state.onboarded, isTrue);
      expect(reloaded.state.selectedChild!.nickname, 'Mae');
    },
  );

  test(
    'sync adapter assigns a production family id and saves onboarding',
    () async {
      final sync = FakeFamilySyncAdapter();
      repo = FamilyRepository(store, sync: sync);

      await onboard();

      expect(repo.state.familyId, 'family_1');
      expect(repo.state.currentCaregiverId, sync.userId);
      expect(repo.state.currentCaregiver!.id, sync.userId);
      expect(sync.savedStates, hasLength(1));
      expect(sync.savedStates.single.familyId, 'family_1');
      expect(sync.previousInviteCodes.single, isEmpty);
    },
  );

  test(
    'attaching sync to an existing local family rekeys owner and attribution',
    () async {
      await onboard();
      final localOwnerId = repo.state.currentCaregiverId;
      await repo.logFeed(FeedKind.bottle);

      final sync = FakeFamilySyncAdapter(userId: 'firebase_uid_1');
      await repo.attachSync(sync);

      expect(repo.state.currentCaregiverId, 'firebase_uid_1');
      expect(repo.state.currentCaregiver!.id, 'firebase_uid_1');
      expect(
        repo.state.caregivers.map((c) => c.id),
        contains('firebase_uid_1'),
      );
      expect(
        repo.state.caregivers.map((c) => c.id),
        isNot(contains(localOwnerId)),
      );
      expect(repo.state.events.single.loggedById, 'firebase_uid_1');
      expect(sync.savedStates, hasLength(1));
      expect(sync.savedStates.single.currentCaregiverId, 'firebase_uid_1');
    },
  );

  test(
    'remote family snapshots update local state and persisted cache',
    () async {
      final sync = FakeFamilySyncAdapter();
      repo = FamilyRepository(store, sync: sync);
      await onboard();

      final remoteFeed = CareEvent(
        id: 'remote_feed',
        childId: repo.state.selectedChildId,
        type: CareEventType.feed,
        startAt: DateTime.now(),
        endAt: DateTime.now(),
        loggedById: repo.state.currentCaregiverId,
        feedKind: FeedKind.bottle,
      );
      sync.emitRemote(repo.state.copyWith(events: [remoteFeed]));
      await Future<void>.delayed(Duration.zero);

      expect(repo.state.events.map((e) => e.id), contains('remote_feed'));
      final raw = await store.read('babyrelay.family.v1');
      expect(raw, contains('remote_feed'));
    },
  );

  test(
    'remote family snapshots preserve this device caregiver identity',
    () async {
      final sync = FakeFamilySyncAdapter();
      repo = FamilyRepository(store, sync: sync);
      await onboard();

      final ownerId = repo.state.currentCaregiverId;
      final joiner = Caregiver(
        id: 'joiner_uid',
        name: 'Nana',
        role: CaregiverRole.caregiver,
        colorIndex: 1,
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      sync.emitRemote(
        repo.state.copyWith(
          caregivers: [...repo.state.caregivers, joiner],
          currentCaregiverId: joiner.id,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repo.state.currentCaregiverId, ownerId);
      expect(repo.state.currentCaregiver!.name, 'Sara');
      expect(repo.state.activeCaregivers.map((c) => c.id), contains(joiner.id));
      final raw = await store.read('babyrelay.family.v1');
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      expect(json['currentCaregiverId'], ownerId);
    },
  );

  test('regenerating invite code asks sync to remove the old code', () async {
    final sync = FakeFamilySyncAdapter();
    repo = FamilyRepository(store, sync: sync);
    await onboard();

    final oldCode = repo.state.inviteCode;
    await repo.regenerateInviteCode();

    expect(repo.state.inviteCode, isNot(oldCode));
    expect(sync.previousInviteCodes.last, oldCode);
  });

  test('join-by-code adopts synced family and persists it locally', () async {
    final child = BabyProfile(
      id: 'baby_1',
      nickname: 'Mae',
      dob: DateTime.now().subtract(const Duration(days: 210)),
      wakeTimeMinutes: 7 * 60,
      bedtimeMinutes: 19 * 60,
      napsPerDayEstimate: 3,
    );
    final owner = Caregiver(
      id: 'owner_1',
      name: 'Sara',
      role: CaregiverRole.owner,
      colorIndex: 0,
      joinedAt: DateTime.now(),
    );
    final sync = FakeFamilySyncAdapter(
      joinedTemplate: FamilyState(
        familyId: 'family_remote',
        children: [child],
        selectedChildId: child.id,
        caregivers: [owner],
        currentCaregiverId: owner.id,
        inviteCode: 'ABC123',
        onboarded: true,
      ),
    );
    repo = FamilyRepository(store, sync: sync);

    await repo.joinFamilyByInviteCode(
      code: 'ABC123',
      caregiverName: 'Alex',
      allowOverFreeCaregiverLimit: false,
    );

    expect(sync.joinedCodes, ['ABC123']);
    expect(repo.state.familyId, 'family_remote');
    expect(repo.state.currentCaregiverId, sync.userId);
    expect(repo.state.activeCaregivers.map((c) => c.name), contains('Alex'));
    expect(await store.read('babyrelay.family.v1'), contains('family_remote'));
  });

  test('join-by-code rejects extra free caregivers for a full team', () async {
    final child = BabyProfile(
      id: 'baby_1',
      nickname: 'Mae',
      dob: DateTime.now().subtract(const Duration(days: 210)),
      wakeTimeMinutes: 7 * 60,
      bedtimeMinutes: 19 * 60,
      napsPerDayEstimate: 3,
    );
    Caregiver caregiver(String id, String name, CaregiverRole role) =>
        Caregiver(
          id: id,
          name: name,
          role: role,
          colorIndex: role == CaregiverRole.owner ? 0 : 1,
          joinedAt: DateTime.now(),
        );
    final sync = FakeFamilySyncAdapter(
      joinedTemplate: FamilyState(
        familyId: 'family_remote',
        children: [child],
        selectedChildId: child.id,
        caregivers: [
          caregiver('owner_1', 'Sara', CaregiverRole.owner),
          caregiver('caregiver_1', 'Sam', CaregiverRole.caregiver),
        ],
        currentCaregiverId: 'owner_1',
        inviteCode: 'ABC123',
        onboarded: true,
      ),
    );
    repo = FamilyRepository(store, sync: sync);

    expect(
      () => repo.joinFamilyByInviteCode(
        code: 'ABC123',
        caregiverName: 'Alex',
        allowOverFreeCaregiverLimit: false,
      ),
      throwsStateError,
    );

    await repo.joinFamilyByInviteCode(
      code: 'ABC123',
      caregiverName: 'Alex',
      allowOverFreeCaregiverLimit: true,
    );
    expect(repo.state.activeCaregivers.map((c) => c.name), contains('Alex'));
  });

  test('persisted JSON carries the schema version and round-trips', () async {
    await onboard();
    await repo.logFeed(FeedKind.bottle);

    final raw = await store.read('babyrelay.family.v1');
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['schemaVersion'], FamilyState.schemaVersion);

    final reloaded = FamilyRepository(store);
    await reloaded.load();
    expect(reloaded.state.events.single.childId, repo.state.selectedChildId);
  });

  test(
    'payload from a newer schema version starts fresh, not corrupt',
    () async {
      await store.write(
        'babyrelay.family.v1',
        jsonEncode({'schemaVersion': FamilyState.schemaVersion + 1}),
      );
      await repo.load();
      expect(repo.state.onboarded, isFalse);
      expect(repo.state.children, isEmpty);
    },
  );

  test(
    'unrecognized payload shapes start fresh (no pre-release migration)',
    () async {
      // Pre-release single-child shape: no children list, events without
      // childId. The app never shipped, so this is treated as corrupt data.
      final preRelease = {
        'baby': {
          'nickname': 'Mae',
          'dob': DateTime(2025, 11, 1).toIso8601String(),
          'wakeTimeMinutes': 420,
          'bedtimeMinutes': 1140,
          'napsPerDayEstimate': 3,
        },
        'events': [
          {
            'id': 'e1',
            'type': 'feed',
            'startAt': DateTime(2026, 6, 9, 9).toIso8601String(),
            'endAt': DateTime(2026, 6, 9, 9).toIso8601String(),
            'loggedById': 'c1',
            'feedKind': 'bottle',
          },
        ],
        'onboarded': true,
      };
      await store.write('babyrelay.family.v1', jsonEncode(preRelease));
      await repo.load();

      expect(repo.state.onboarded, isFalse);
      expect(repo.state.children, isEmpty);
      expect(repo.state.events, isEmpty);
    },
  );

  test('exportJson wraps the data in a versioned envelope', () async {
    await onboard();
    final export = jsonDecode(repo.exportJson()) as Map<String, dynamic>;
    expect(export['app'], 'BabyRelay');
    expect(export['schemaVersion'], FamilyState.schemaVersion);
    expect(export['exportedAt'], isNotNull);
    final family = export['family'] as Map<String, dynamic>;
    expect(family['children'], hasLength(1));
  });

  test('addChild selects the new child; selectChild switches back', () async {
    await onboard();
    final mae = repo.state.selectedChild!;
    final theo = await addSibling();

    expect(repo.state.children, hasLength(2));
    expect(repo.state.selectedChildId, theo.id);
    expect(theo.colorIndex, isNot(mae.colorIndex));

    await repo.selectChild(mae.id);
    expect(repo.state.selectedChildId, mae.id);

    // Selecting an unknown id is a no-op.
    await repo.selectChild('nope');
    expect(repo.state.selectedChildId, mae.id);
  });

  test('events are isolated per child', () async {
    await onboard();
    final mae = repo.state.selectedChild!;
    final theo = await addSibling();

    // Log for Theo (selected after add).
    await repo.logFeed(FeedKind.solids);
    await repo.startSleep();

    // Switch to Mae and log differently.
    await repo.selectChild(mae.id);
    await repo.logDiaper(DiaperKind.wet);

    final now = DateTime.now();
    expect(repo.state.eventsOn(now, childId: theo.id), hasLength(2));
    expect(repo.state.eventsOn(now, childId: mae.id), hasLength(1));
    expect(repo.state.eventsOn(now), hasLength(1)); // selected = Mae

    // Sleep state is per child: Theo asleep, Mae awake.
    expect(repo.state.isChildAsleep(theo.id), isTrue);
    expect(repo.state.isChildAsleep(mae.id), isFalse);
    expect(repo.state.isAsleep, isFalse);

    // Both children can sleep at once without double-start conflicts.
    final maeSleep = await repo.startSleep();
    expect(maeSleep, isNotNull);
    expect(repo.state.isAsleep, isTrue);

    // Ending sleep only ends the selected child's.
    await repo.endSleep();
    expect(repo.state.isChildAsleep(mae.id), isFalse);
    expect(repo.state.isChildAsleep(theo.id), isTrue);
  });

  test(
    'removeChild deletes their events and reselects a remaining child',
    () async {
      await onboard();
      final mae = repo.state.selectedChild!;
      final theo = await addSibling();
      await repo.logFeed(FeedKind.bottle); // Theo's event
      await repo.selectChild(mae.id);
      await repo.logFeed(FeedKind.nursing); // Mae's event

      await repo.removeChild(theo.id);
      expect(repo.state.children.map((c) => c.id), [mae.id]);
      expect(repo.state.events.every((e) => e.childId == mae.id), isTrue);

      // Removing the selected child moves selection to the remaining one.
      final iris = await addSibling(name: 'Iris');
      expect(repo.state.selectedChildId, iris.id);
      await repo.removeChild(iris.id);
      expect(repo.state.selectedChildId, mae.id);
    },
  );

  test('sleep toggle: start then end, no double-start', () async {
    await onboard();
    final started = await repo.startSleep();
    expect(started, isNotNull);
    expect(started!.childId, repo.state.selectedChildId);
    expect(repo.state.isAsleep, isTrue);

    final doubleStart = await repo.startSleep();
    expect(doubleStart, isNull);

    final ended = await repo.endSleep();
    expect(ended!.endAt, isNotNull);
    expect(repo.state.isAsleep, isFalse);
  });

  test(
    'overlapping sleeps are detected per child and merge into one span',
    () async {
      await onboard();
      final day = DateTime.now();
      DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

      final a = (await repo.startSleep(at: at(13, 0)))!;
      await repo.endSleep(at: at(13, 50));
      final aDone = repo.state.events.firstWhere((e) => e.id == a.id);

      // A second caregiver logs the same nap with slightly different times.
      final manual = (await repo.startSleep(at: at(13, 10)))!;
      await repo.endSleep(at: at(14, 0));

      // A sibling's overlapping sleep must NOT count as an overlap.
      final mae = repo.state.selectedChild!;
      final theo = await addSibling();
      await repo.startSleep(at: at(13, 5), childId: theo.id);
      await repo.endSleep(at: at(13, 40), childId: theo.id);
      await repo.selectChild(mae.id);

      final overlaps = repo.overlappingSleeps(aDone);
      expect(overlaps.map((e) => e.id), [manual.id]);

      final merged = await repo.mergeSleepEvents(aDone, overlaps.first);
      expect(merged.startAt, at(13, 0));
      expect(merged.endAt, at(14, 0));
      expect(merged.merged, isTrue);
      expect(merged.childId, mae.id);
      expect(
        repo.state.events.where((e) => e.isSleep && e.childId == mae.id).length,
        1,
      );
    },
  );

  test('edit records attribution and delete removes the entry', () async {
    await onboard();
    final feed = await repo.logFeed(FeedKind.bottle);
    await repo.updateEvent(feed.copyWith(note: 'Took 4oz'));
    final updated = repo.state.events.firstWhere((e) => e.id == feed.id);
    expect(updated.note, 'Took 4oz');
    expect(updated.editedByIds, contains(repo.state.currentCaregiverId));

    await repo.deleteEvent(feed.id);
    expect(repo.state.events, isEmpty);
  });

  test('caregiver removal keeps attribution but deactivates them', () async {
    await onboard();
    final partner = await repo.addCaregiver('Sam');
    expect(repo.state.activeCaregivers, hasLength(2));

    await repo.removeCaregiver(partner.id);
    expect(repo.state.activeCaregivers, hasLength(1));
    // Still in the list for attribution.
    expect(
      repo.state.caregivers.where((c) => c.id == partner.id),
      hasLength(1),
    );
  });

  test(
    'recentNapCounts counts only the child\'s completed day sleeps',
    () async {
      await onboard();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      DateTime y(int h) =>
          DateTime(yesterday.year, yesterday.month, yesterday.day, h);

      await repo.startSleep(at: y(9));
      await repo.endSleep(at: y(10));
      await repo.startSleep(at: y(13));
      await repo.endSleep(at: y(14));
      // Night sleep should not count as a nap.
      await repo.startSleep(at: y(20));
      await repo.endSleep(at: y(22));

      // Sibling naps must not leak into Mae's counts.
      final mae = repo.state.selectedChild!;
      final theo = await addSibling();
      await repo.startSleep(at: y(11), childId: theo.id);
      await repo.endSleep(at: y(12), childId: theo.id);
      await repo.selectChild(mae.id);

      expect(repo.recentNapCounts(now: today), [2]);
      expect(repo.recentNapCounts(now: today, childId: theo.id), [1]);
    },
  );

  test('loadSampleDay seeds the selected child and a demo sibling', () async {
    await onboard();
    final mae = repo.state.selectedChild!;
    await repo.loadSampleDay();

    expect(repo.state.children.length, 2);
    final sibling = repo.state.children.firstWhere((c) => c.id != mae.id);
    expect(repo.state.eventsForChild(mae.id), isNotEmpty);
    expect(repo.state.eventsForChild(sibling.id), isNotEmpty);
    // Selection stays on the original child.
    expect(repo.state.selectedChildId, mae.id);
  });

  test('deleteAllData wipes state and storage', () async {
    await onboard();
    await repo.logFeed(FeedKind.bottle);
    await repo.deleteAllData();
    expect(repo.state.onboarded, isFalse);
    expect(repo.state.children, isEmpty);
    expect(repo.state.events, isEmpty);
    expect(await store.read('babyrelay.family.v1'), isNull);
  });

  test('deleteAllData deletes the remote family for the owner', () async {
    final sync = FakeFamilySyncAdapter();
    repo = FamilyRepository(store, sync: sync);
    await onboard();

    final familyId = repo.state.familyId;
    await repo.deleteAllData();

    expect(sync.deletedFamilyIds, [familyId]);
  });
}

class FakeFamilySyncAdapter implements FamilySyncAdapter {
  FakeFamilySyncAdapter({this.joinedTemplate, this.userId = 'sync-user'});

  final FamilyState? joinedTemplate;
  final savedStates = <FamilyState>[];
  final previousInviteCodes = <String>[];
  final joinedCodes = <String>[];
  final deletedFamilyIds = <String>[];
  final _controller = StreamController<FamilyState>.broadcast();
  int _familyCounter = 0;

  @override
  final String userId;

  @override
  String newFamilyId() => 'family_${++_familyCounter}';

  @override
  Stream<FamilyState> watchFamily(String familyId) => _controller.stream;

  @override
  Future<void> saveFamily(
    FamilyState state, {
    String? previousInviteCode,
  }) async {
    savedStates.add(state);
    previousInviteCodes.add(previousInviteCode ?? '');
  }

  void emitRemote(FamilyState state) => _controller.add(state);

  @override
  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  }) async {
    joinedCodes.add(code);
    final template = joinedTemplate ?? const FamilyState();
    final wouldIncreaseActiveMembers = !template.caregivers.any(
      (c) => c.id == caregiver.id && c.isActive,
    );
    if (!allowOverFreeCaregiverLimit &&
        wouldIncreaseActiveMembers &&
        template.activeCaregivers.length >= freeCaregiverLimit) {
      throw StateError('This care team is full on the free plan.');
    }
    return template.copyWith(
      caregivers: [...template.caregivers, caregiver],
      currentCaregiverId: caregiver.id,
      onboarded: true,
    );
  }

  @override
  Future<void> deleteFamily(FamilyState state) async {
    deletedFamilyIds.add(state.familyId);
  }

  @override
  Future<void> dispose() => _controller.close();
}
