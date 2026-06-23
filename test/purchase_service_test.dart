import 'package:babyrelay/core/purchases/purchase_service.dart';
import 'package:babyrelay/data/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryStore store;
  late LocalPurchaseService purchases;

  setUp(() {
    store = InMemoryStore();
    purchases = LocalPurchaseService(store, actionDelay: Duration.zero);
  });

  Plan specialAnnual() =>
      purchases.plans.firstWhere((p) => p.id == PlanId.specialAnnual);
  Plan annual() => purchases.plans.firstWhere((p) => p.id == PlanId.annual);

  test('catalog exposes offer, annual, and monthly plans with product ids', () {
    expect(purchases.plans.map((p) => p.id), [
      PlanId.specialAnnual,
      PlanId.annual,
      PlanId.monthly,
    ]);
    expect(purchases.plans.map((p) => p.productId), everyElement(isNotEmpty));
    expect(specialAnnual().productId, ProductIds.specialAnnual);
    expect(specialAnnual().isSpecialOffer, isTrue);
    expect(specialAnnual().trialDays, 0);
    expect(specialAnnual().countdownSeconds, 90);
    expect(PurchaseService.entitlementId, 'pro');
  });

  test('product ids map to plans with Google Play base-plan suffixes', () {
    expect(
      ProductIds.planFor('babyrelay_pro_special_annual:special-annual'),
      PlanId.specialAnnual,
    );
    expect(ProductIds.planFor('babyrelay_pro_annual:annual'), PlanId.annual);
    expect(ProductIds.planFor('babyrelay_pro_monthly:monthly'), PlanId.monthly);
  });

  test('special annual purchase grants pro without a trial', () async {
    final outcome = await purchases.purchase(specialAnnual());
    expect(outcome, PurchaseOutcome.success);
    expect(purchases.isPro, isTrue);
    expect(purchases.activePlan, PlanId.specialAnnual);
    expect(purchases.inTrial, isFalse);
    expect(purchases.trialEndsAt, isNull);
  });

  test('successful purchase grants pro with a trial and persists', () async {
    final outcome = await purchases.purchase(annual());
    expect(outcome, PurchaseOutcome.success);
    expect(purchases.isPro, isTrue);
    expect(purchases.activePlan, PlanId.annual);
    expect(purchases.inTrial, isTrue);
    expect(purchases.lastErrorMessage, isNull);

    // A fresh service (reinstall/app restart) sees the entitlement.
    final reloaded = LocalPurchaseService(store, actionDelay: Duration.zero);
    await reloaded.load();
    expect(reloaded.isPro, isTrue);
    expect(reloaded.activePlan, PlanId.annual);
  });

  test('cancelled purchase leaves the free tier, no error surfaced', () async {
    purchases.nextPurchaseOutcome = PurchaseOutcome.cancelled;
    final outcome = await purchases.purchase(annual());
    expect(outcome, PurchaseOutcome.cancelled);
    expect(purchases.isPro, isFalse);
    expect(purchases.lastErrorMessage, isNull);
  });

  test('failed purchase surfaces an error message and stays free', () async {
    purchases.nextPurchaseOutcome = PurchaseOutcome.failed;
    final outcome = await purchases.purchase(annual());
    expect(outcome, PurchaseOutcome.failed);
    expect(purchases.isPro, isFalse);
    expect(purchases.lastErrorMessage, isNotNull);

    // The next attempt defaults back to the normal path.
    expect(await purchases.purchase(annual()), PurchaseOutcome.success);
  });

  test('restore finds a previous purchase or reports nothing', () async {
    expect(await purchases.restore(), RestoreOutcome.nothingToRestore);

    await purchases.purchase(annual());
    final fresh = LocalPurchaseService(store, actionDelay: Duration.zero);
    expect(await fresh.restore(), RestoreOutcome.restored);
    expect(fresh.isPro, isTrue);
  });

  test('restore failure reports an error without changing state', () async {
    purchases.failNextRestore = true;
    expect(await purchases.restore(), RestoreOutcome.failed);
    expect(purchases.lastErrorMessage, isNotNull);
    expect(purchases.isPro, isFalse);
  });

  test('busy guard rejects overlapping requests', () async {
    final slow = LocalPurchaseService(
      store,
      actionDelay: const Duration(milliseconds: 50),
    );
    final first = slow.purchase(annual());
    expect(slow.busy, isTrue);
    expect(await slow.purchase(annual()), PurchaseOutcome.failed);
    expect(await first, PurchaseOutcome.success);
    expect(slow.busy, isFalse);
  });

  test('clearEntitlement drops back to the free tier and persists', () async {
    await purchases.purchase(annual());
    await purchases.clearEntitlement();
    expect(purchases.isPro, isFalse);
    expect(purchases.activePlan, isNull);

    final reloaded = LocalPurchaseService(store, actionDelay: Duration.zero);
    await reloaded.load();
    expect(reloaded.isPro, isFalse);
  });

  test('corrupt entitlement cache loads as free tier', () async {
    await store.write('babyrelay.purchases.v1', 'not json');
    await purchases.load();
    expect(purchases.isPro, isFalse);
  });
}
