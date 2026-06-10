import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FamilyRepository repo;
  late InMemoryStore store;

  Future<void> onboard() async {
    await repo.completeOnboarding(
      baby: BabyProfile(
        nickname: 'Mae',
        dob: DateTime.now().subtract(const Duration(days: 210)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60,
        napsPerDayEstimate: 3,
      ),
      primaryCaregiverName: 'Sara',
    );
  }

  setUp(() {
    store = InMemoryStore();
    repo = FamilyRepository(store);
  });

  test('onboarding creates owner, invite code and persists', () async {
    await onboard();
    expect(repo.state.onboarded, isTrue);
    expect(repo.state.activeCaregivers, hasLength(1));
    expect(repo.state.currentCaregiver!.isOwner, isTrue);
    expect(repo.state.inviteCode, hasLength(6));

    // Round-trips through persistence.
    final reloaded = FamilyRepository(store);
    await reloaded.load();
    expect(reloaded.state.onboarded, isTrue);
    expect(reloaded.state.baby!.nickname, 'Mae');
  });

  test('sleep toggle: start then end, no double-start', () async {
    await onboard();
    final started = await repo.startSleep();
    expect(started, isNotNull);
    expect(repo.state.isAsleep, isTrue);

    final doubleStart = await repo.startSleep();
    expect(doubleStart, isNull);

    final ended = await repo.endSleep();
    expect(ended!.endAt, isNotNull);
    expect(repo.state.isAsleep, isFalse);
  });

  test('overlapping sleeps are detected and merge into one span', () async {
    await onboard();
    final day = DateTime.now();
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

    final a = (await repo.startSleep(at: at(13, 0)))!;
    await repo.endSleep(at: at(13, 50));
    final aDone = repo.state.events.firstWhere((e) => e.id == a.id);

    // A second caregiver logs the same nap with slightly different times.
    final manual = (await repo.startSleep(at: at(13, 10)))!;
    await repo.endSleep(at: at(14, 0));

    final overlaps = repo.overlappingSleeps(aDone);
    expect(overlaps.map((e) => e.id), contains(manual.id));

    final merged = await repo.mergeSleepEvents(aDone, overlaps.first);
    expect(merged.startAt, at(13, 0));
    expect(merged.endAt, at(14, 0));
    expect(merged.merged, isTrue);
    expect(repo.state.events.where((e) => e.isSleep).length, 1);
  });

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

  test('recentNapCounts counts only completed day sleeps per day', () async {
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

    final counts = repo.recentNapCounts(now: today);
    expect(counts, [2]);
  });

  test('deleteAllData wipes state and storage', () async {
    await onboard();
    await repo.logFeed(FeedKind.bottle);
    await repo.deleteAllData();
    expect(repo.state.onboarded, isFalse);
    expect(repo.state.events, isEmpty);
    expect(await store.read('babyrelay.family.v1'), isNull);
  });
}
