import 'package:babyrelay/app/app.dart';
import 'package:babyrelay/core/analytics/analytics_service.dart';
import 'package:babyrelay/core/purchases/purchase_service.dart';
import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(FamilyRepository, PurchaseService)> buildDeps({
    bool onboarded = false,
  }) async {
    final store = InMemoryStore();
    final repo = FamilyRepository(store);
    final purchases = PurchaseService(store);
    if (onboarded) {
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
    return (repo, purchases);
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

    expect(find.textContaining('One baby.'), findsOneWidget);
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

  testWidgets('handoff opens from Today and shows summary', (tester) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Handoff to next caregiver'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Handoff for Mae'), findsOneWidget);
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
    expect(find.text('Start 7-day free trial'), findsOneWidget);
  });

  testWidgets('settings shows privacy and integration placeholders', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Delete all data'), findsOneWidget);
    expect(find.text('Export my data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('RevenueCat'), 200);
    expect(find.text('RevenueCat'), findsOneWidget);
  });
}
