import 'package:babyrelay/app/app.dart';
import 'package:babyrelay/core/analytics/analytics_service.dart';
import 'package:babyrelay/core/purchases/purchase_service.dart';
import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(FamilyRepository, LocalPurchaseService)> buildDeps({
    bool onboarded = false,
  }) async {
    final store = InMemoryStore();
    final repo = FamilyRepository(store);
    final purchases = LocalPurchaseService(store, actionDelay: Duration.zero);
    if (onboarded) {
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
    return (repo, purchases);
  }

  Future<BabyProfile> addSibling(FamilyRepository repo) {
    return repo.addChild(
      BabyProfile(
        id: '',
        nickname: 'Theo',
        dob: DateTime.now().subtract(const Duration(days: 480)),
        wakeTimeMinutes: 7 * 60,
        bedtimeMinutes: 19 * 60 + 30,
        napsPerDayEstimate: 1,
      ),
    );
  }

  Widget app(FamilyRepository repo, PurchaseService purchases) => BabyRelayApp(
    familyRepository: repo,
    purchaseService: purchases,
    analytics: AnalyticsService(),
  );

  testWidgets('fresh install lands on onboarding', (tester) async {
    final (repo, purchases) = await buildDeps();
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    expect(find.textContaining('Every caregiver.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('onboarded user lands on Today and can log sleep one-tap', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    // Today surface.
    expect(find.text('Mae'), findsOneWidget);
    expect(find.text('Asleep'), findsOneWidget);

    // One tap: asleep.
    await tester.tap(find.text('Asleep'));
    await tester.pumpAndSettle();
    expect(repo.state.isAsleep, isTrue);
    expect(find.text('Awake'), findsWidgets);

    // One tap: awake — timeline now has a completed sleep.
    await tester.tap(find.text('Awake').first);
    await tester.pumpAndSettle();
    expect(repo.state.isAsleep, isFalse);
    expect(repo.state.events.where((e) => e.isSleep), hasLength(1));
  });

  testWidgets('child switcher swaps Today to the selected child', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    final mae = repo.state.selectedChild!;
    await addSibling(repo);
    await repo.selectChild(mae.id);
    // Distinct logs per child.
    await repo.logFeed(FeedKind.bottle, childId: mae.id);
    final theoId = repo.state.children.firstWhere((c) => c.id != mae.id).id;
    await repo.startSleep(childId: theoId);

    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    // Header shows Mae; the switcher strip shows both children.
    expect(find.text('Mae'), findsWidgets);
    expect(find.text('Theo'), findsOneWidget);
    expect(find.text('Bottle', skipOffstage: false), findsOneWidget);

    // Tap Theo's pill → Today re-scopes: his ongoing sleep, not Mae's feed.
    await tester.tap(find.text('Theo'));
    await tester.pumpAndSettle();
    expect(repo.state.selectedChildId, theoId);
    expect(repo.state.isAsleep, isTrue);
    expect(find.text('Bottle', skipOffstage: false), findsNothing);
    // Sleep button now offers to log the wake-up.
    expect(find.text('Awake'), findsOneWidget);
  });

  testWidgets('child switcher sheet lists children and add-child row', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await addSibling(repo);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    // The header name (chevron) opens the family sheet.
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Your children'), findsOneWidget);
    expect(find.text('Add a child'), findsOneWidget);
  });

  testWidgets('handoff opens from Today and shows summary', (tester) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Handoff to next caregiver'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HANDOFF FOR MAE'), findsOneWidget);
    expect(find.text('Share handoff'), findsOneWidget);
    expect(find.text('Copy as text'), findsOneWidget);
  });

  testWidgets('care team shows owner and paywall gates beyond free limit', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await repo.addCaregiver('Sam'); // free slot used up
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Care team'));
    await tester.pumpAndSettle();

    expect(find.text('Sara (you)'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.text('Invite a caregiver'));
    await tester.pumpAndSettle();

    // Over the free limit → paywall.
    expect(find.text('Claim annual offer'), findsOneWidget);
    expect(find.text('Offer ends in'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets(
    'settings lists children and add-child gates on paywall for free tier',
    (tester) async {
      final (repo, purchases) = await buildDeps(onboarded: true);
      await tester.pumpWidget(app(repo, purchases));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Mae'), findsOneWidget);
      expect(find.text('Add a child'), findsOneWidget);

      // Free tier already has one child → paywall.
      await tester.tap(find.text('Add a child'));
      await tester.pumpAndSettle();
      expect(find.text('Claim annual offer'), findsOneWidget);
      expect(find.text('Offer ends in'), findsOneWidget);
    },
  );

  testWidgets('settings shows privacy rows and integration statuses', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Delete all data'), findsOneWidget);
    expect(find.text('Export my data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Contact support'), 200);
    expect(find.text('Contact support'), findsOneWidget);
    // No provider keys in this test build → every seam reads not configured.
    await tester.scrollUntilVisible(find.text('Gleap'), 200);
    expect(find.text('RevenueCat'), findsOneWidget);
    expect(find.text('Not configured'), findsNWidgets(4));
  });

  testWidgets('paywall purchase flow covers success, cancel, and failure', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await repo.addCaregiver('Sam');
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    Future<void> openPaywall() async {
      await tester.tap(find.text('Care team'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite a caregiver'));
      await tester.pumpAndSettle();
    }

    // Cancelled: stays on the paywall, still free, no error copy.
    await openPaywall();
    purchases.nextPurchaseOutcome = PurchaseOutcome.cancelled;
    await tester.tap(find.text('Claim annual offer'));
    await tester.pumpAndSettle();
    expect(purchases.isPro, isFalse);
    expect(find.text('Claim annual offer'), findsOneWidget);

    // Failed: stays free and surfaces the error.
    purchases.nextPurchaseOutcome = PurchaseOutcome.failed;
    await tester.tap(find.text('Claim annual offer'));
    await tester.pumpAndSettle();
    expect(purchases.isPro, isFalse);
    expect(find.textContaining('could not be completed'), findsOneWidget);

    // Success: entitlement granted and the paywall dismisses.
    await tester.tap(find.text('Claim annual offer'));
    await tester.pumpAndSettle();
    expect(purchases.isPro, isTrue);
    expect(find.text('Claim annual offer'), findsNothing);
  });

  testWidgets('restore with no purchase reports nothing to restore', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await repo.addCaregiver('Sam');
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Care team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite a caregiver'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(purchases.isPro, isFalse);
    expect(find.text('No previous purchase found'), findsOneWidget);
  });
}
