import 'dart:async';

import 'package:babyrelay/app/app.dart';
import 'package:babyrelay/core/analytics/analytics_service.dart';
import 'package:babyrelay/core/attribution/attribution_service.dart';
import 'package:babyrelay/core/purchases/purchase_service.dart';
import 'package:babyrelay/core/reviews/review_prompt_service.dart';
import 'package:babyrelay/core/support/support_service.dart';
import 'package:babyrelay/core/tutorial/tutorial_service.dart';
import 'package:babyrelay/data/family_repository.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:babyrelay/domain/models/baby_profile.dart';
import 'package:babyrelay/domain/models/care_event.dart';
import 'package:babyrelay/domain/models/caregiver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(FamilyRepository, LocalPurchaseService)> buildDeps({
    bool onboarded = false,
    FamilySyncAdapter? sync,
  }) async {
    final store = InMemoryStore();
    final repo = FamilyRepository(store, sync: sync);
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

  Widget app(
    FamilyRepository repo,
    PurchaseService purchases, {
    TutorialService? tutorialService,
    ReviewPromptService? reviewPromptService,
  }) {
    return BabyRelayApp(
      familyRepository: repo,
      purchaseService: purchases,
      analytics: AnalyticsService(),
      supportService: SupportService.disabled(),
      attributionService: AttributionService(apiKey: ''),
      tutorialService: tutorialService ?? TutorialService.disabled(),
      reviewPromptService:
          reviewPromptService ?? ReviewPromptService.disabled(),
    );
  }

  testWidgets('fresh install lands on onboarding', (tester) async {
    final (repo, purchases) = await buildDeps();
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    expect(find.textContaining('Every caregiver.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('new caregiver can reach join screen before onboarding', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps();
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();

    expect(find.text('Join a care team'), findsOneWidget);
    expect(find.text('Set up a new family instead'), findsOneWidget);
    expect(find.textContaining('local preview'), findsOneWidget);
  });

  testWidgets('onboarding finishes at paywall without a rating gate', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps();
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mae');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sara');
    await tester.pump();
    await tester.tap(find.text('Create our timeline'));
    await tester.pumpAndSettle();

    expect(repo.state.onboarded, isTrue);
    expect(find.text('Claim annual offer'), findsOneWidget);
    expect(find.text('Offer ends in'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('Is BabyRelay already feeling helpful?'), findsNothing);
    expect(find.text('Did that handoff help?'), findsNothing);

    await tester.scrollUntilVisible(find.text('Monthly'), 200);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.text('Choose monthly'), findsOneWidget);
    expect(find.text('\$9.99/month today. Cancel anytime.'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
  });

  testWidgets('Today coach marks wait until onboarding paywall is dismissed', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps();
    final tutorials = TutorialService(InMemoryStore());
    await tutorials.load();

    await tester.pumpWidget(app(repo, purchases, tutorialService: tutorials));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Mae');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sara');
    await tester.pump();
    await tester.tap(find.text('Create our timeline'));
    await tester.pumpAndSettle();

    expect(find.text('Claim annual offer'), findsOneWidget);
    expect(find.text('Start with one tap'), findsNothing);
    expect(tutorials.shouldShow(TutorialIds.todayIntro), isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Start with one tap'), findsOneWidget);
    expect(tutorials.shouldShow(TutorialIds.todayIntro), isTrue);
  });

  testWidgets('onboarded user lands on Today and can log sleep one-tap', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    // Today surface.
    expect(find.text('Mae'), findsOneWidget);
    expect(find.text('Start sleep'), findsOneWidget);

    // One tap: asleep.
    await tester.tap(find.text('Start sleep'));
    await tester.pumpAndSettle();
    expect(repo.state.isAsleep, isTrue);
    expect(find.text('End sleep'), findsWidgets);

    // One tap: awake — timeline now has a completed sleep.
    await tester.ensureVisible(find.text('End sleep').first);
    await tester.tap(find.text('End sleep').first);
    await tester.pumpAndSettle();
    expect(repo.state.isAsleep, isFalse);
    expect(repo.state.events.where((e) => e.isSleep), hasLength(1));
  });

  testWidgets('Today sleep tools support backdated and manual sleep logs', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    await tester.pumpWidget(app(repo, purchases));
    await tester.pumpAndSettle();

    expect(find.text('Sleep today', skipOffstage: false), findsOneWidget);
    expect(find.text('Fell asleep 10 min ago'), findsOneWidget);
    expect(find.text('Add past sleep'), findsOneWidget);

    await tester.tap(find.text('Fell asleep 10 min ago'));
    await tester.pumpAndSettle();

    expect(repo.state.isAsleep, isTrue);
    final ongoing = repo.state.ongoingSleep!;
    expect(
      DateTime.now().difference(ongoing.startAt).inMinutes,
      greaterThanOrEqualTo(9),
    );
    expect(find.text('Woke up 10 min ago'), findsOneWidget);
    expect(find.text('Adjust sleep start'), findsOneWidget);

    await tester.tap(find.text('Woke up 10 min ago'));
    await tester.pumpAndSettle();
    expect(repo.state.isAsleep, isFalse);

    await tester.tap(find.text('Add past sleep'));
    await tester.pumpAndSettle();
    expect(find.text('For the nap someone forgot to start.'), findsOneWidget);

    await tester.tap(find.text('Last 45 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add sleep'));
    await tester.pumpAndSettle();

    final sleeps = repo.state.events.where((e) => e.isSleep).toList();
    expect(sleeps, hasLength(2));
    final manual = sleeps.firstWhere((e) => e.duration?.inMinutes == 45);
    expect(manual.endAt, isNotNull);
    expect(repo.state.isAsleep, isFalse);
  });

  testWidgets('tracking action can trigger the timely native review prompt', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    final reviews = ReviewPromptService(InMemoryStore());
    await reviews.load();

    await tester.pumpWidget(app(repo, purchases, reviewPromptService: reviews));
    await tester.pumpAndSettle();

    expect(find.text('Did that log help?'), findsNothing);

    await tester.tap(find.text('Start sleep'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(repo.state.isAsleep, isTrue);
    expect(find.text('Did that log help?'), findsOneWidget);
    expect(find.text('Yes, it helped'), findsOneWidget);
    expect(find.text('Needs work'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);

    await tester.tap(find.text('Needs work'));
    await tester.pumpAndSettle();
    expect(reviews.shouldShow(ReviewPromptIds.trackingSuccess), isFalse);
    expect(reviews.shouldShow(ReviewPromptIds.handoffSuccess), isFalse);
  });

  testWidgets('Today coach marks show once and persist when skipped', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    final tutorials = TutorialService(InMemoryStore());
    await tutorials.load();

    await tester.pumpWidget(app(repo, purchases, tutorialService: tutorials));
    await tester.pumpAndSettle();

    expect(find.text('Start with one tap'), findsOneWidget);
    expect(find.text('Skip tour'), findsOneWidget);

    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();

    expect(tutorials.shouldShow(TutorialIds.todayIntro), isFalse);
    expect(find.text('Start with one tap'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(repo, purchases, tutorialService: tutorials));
    await tester.pumpAndSettle();

    expect(find.text('Start with one tap'), findsNothing);
    expect(find.text('Start sleep'), findsOneWidget);
  });

  testWidgets('Care Team coach marks complete and do not repeat', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    final tutorials = TutorialService(InMemoryStore());
    await tutorials.load();
    await tutorials.markSeen(TutorialIds.todayIntro);

    await tester.pumpWidget(app(repo, purchases, tutorialService: tutorials));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Care team'));
    await tester.pumpAndSettle();

    expect(find.text('Invite the people who help'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Everyone stays in sync'), findsWidgets);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tutorials.shouldShow(TutorialIds.careTeam), isFalse);
    expect(find.text('Invite the people who help'), findsNothing);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Care team'));
    await tester.pumpAndSettle();

    expect(find.text('Invite the people who help'), findsNothing);
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
    await tester.scrollUntilVisible(
      find.text('Bottle'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bottle'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, 500), 1000);
    await tester.pumpAndSettle();

    // Tap Theo's pill → Today re-scopes: his ongoing sleep, not Mae's feed.
    await tester.tap(find.text('Theo'));
    await tester.pumpAndSettle();
    expect(repo.state.selectedChildId, theoId);
    expect(repo.state.isAsleep, isTrue);
    expect(find.text('Bottle', skipOffstage: false), findsNothing);
    // Sleep button now offers to log the wake-up.
    expect(find.text('End sleep'), findsOneWidget);
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
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    final appHeight = tester.getSize(find.byType(MaterialApp)).height;
    expect(sheetRect.bottom, closeTo(appHeight, 0.1));
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
    expect(find.text('Today'), findsNothing);
    expect(find.text('Care team'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('handoff copy is the timely native review prompt moment', (
    tester,
  ) async {
    final (repo, purchases) = await buildDeps(onboarded: true);
    final reviews = ReviewPromptService(InMemoryStore());
    await reviews.load();
    await repo.logFeed(FeedKind.bottle);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') return null;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(app(repo, purchases, reviewPromptService: reviews));
    await tester.pumpAndSettle();

    expect(find.text('Did that handoff help?'), findsNothing);

    await tester.tap(find.text('Handoff to next caregiver'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copy as text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy as text'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Did that handoff help?'), findsOneWidget);
    expect(find.text('Yes, it helped'), findsOneWidget);
    expect(find.text('Needs work'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(reviews.shouldShow(ReviewPromptIds.handoffSuccess), isFalse);

    await tester.ensureVisible(find.text('Copy as text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy as text'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Did that handoff help?'), findsNothing);
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
    expect(find.text('Today'), findsNothing);
    expect(find.text('Care team'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets(
    'Firebase-enabled invite sheet hides local caregiver add shortcut',
    (tester) async {
      final (repo, purchases) = await buildDeps(
        onboarded: true,
        sync: _UiFakeFamilySyncAdapter(),
      );
      await tester.pumpWidget(app(repo, purchases));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Care team'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite a caregiver'));
      await tester.pumpAndSettle();

      expect(find.text('Invite a caregiver'), findsWidgets);
      expect(find.text('Add caregiver on this device'), findsNothing);
      expect(find.textContaining('babyrelay.app/join'), findsOneWidget);
    },
  );

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
    expect(find.text('Superwall'), findsOneWidget);
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

class _UiFakeFamilySyncAdapter implements FamilySyncAdapter {
  final _controller = StreamController<FamilyState>.broadcast();
  int _familyCounter = 0;

  @override
  String get userId => 'firebase-owner';

  @override
  String newFamilyId() => 'family_${++_familyCounter}';

  @override
  Stream<FamilyState> watchFamily(String familyId) => _controller.stream;

  @override
  Future<void> saveFamily(
    FamilyState state, {
    String? previousInviteCode,
  }) async {}

  @override
  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCurrentUserRemoteData(FamilyState state) async {}

  @override
  Future<bool> deleteCurrentAuthIdentity() async => true;

  @override
  Future<void> dispose() => _controller.close();
}
