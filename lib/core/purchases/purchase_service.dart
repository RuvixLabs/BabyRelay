import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_store.dart';

enum PlanId { specialAnnual, annual, monthly }

/// Store product identifiers. The RevenueCat offering maps them to [PlanId]s,
/// so nothing else in the app touches raw product ids.
abstract final class ProductIds {
  static const String specialAnnual = 'babyrelay_pro_special_annual';
  static const String monthly = 'babyrelay_pro_monthly';
  static const String annual = 'babyrelay_pro_annual';
}

class Plan {
  const Plan({
    required this.id,
    required this.productId,
    required this.title,
    required this.priceLabel,
    required this.periodLabel,
    required this.trialDays,
    this.originalPriceLabel,
    this.badge,
    this.subline,
    this.isSpecialOffer = false,
  });

  final PlanId id;
  final String productId;
  final String title;
  final String priceLabel;
  final String periodLabel;
  final int trialDays;
  final String? originalPriceLabel;
  final String? badge;
  final String? subline;
  final bool isSpecialOffer;
}

/// Outcome of a purchase attempt. `cancelled` is the user backing out of the
/// store sheet — not an error, never shown as one.
enum PurchaseOutcome { success, cancelled, failed }

/// Outcome of a restore attempt. `nothingToRestore` is the common "new
/// device, never purchased" case and gets neutral copy, not an error.
enum RestoreOutcome { restored, nothingToRestore, failed }

/// Subscription seam. Screens depend only on this interface; the shipped
/// implementation today is [LocalPurchaseService], and the RevenueCat-backed
/// one replaces it behind the same surface once `REVENUECAT_API_KEY` is
/// provided (entitlement id: [entitlementId]).
abstract class PurchaseService extends ChangeNotifier {
  static const entitlementId = 'pro';

  bool get isPro;
  PlanId? get activePlan;
  DateTime? get trialEndsAt;

  /// True while a purchase or restore is in flight; buttons disable on it.
  bool get busy;

  /// Human-readable reason for the last [PurchaseOutcome.failed] /
  /// [RestoreOutcome.failed], for the error snackbar.
  String? get lastErrorMessage;

  /// Plans to offer. Local builds use a fixed catalog; the RevenueCat
  /// implementation builds these from the current offering so price strings
  /// always come from the store.
  List<Plan> get plans;

  bool get inTrial =>
      isPro && trialEndsAt != null && DateTime.now().isBefore(trialEndsAt!);

  Future<void> load();
  Future<PurchaseOutcome> purchase(Plan plan);
  Future<RestoreOutcome> restore();
}

/// On-device implementation: simulates the store flow and persists the
/// entitlement locally. Explicitly NOT a billing system — it exists so the
/// whole paywall/entitlement UX is real and testable before RevenueCat lands.
class LocalPurchaseService extends PurchaseService {
  LocalPurchaseService(this._store, {Duration? actionDelay})
    : _actionDelay = actionDelay ?? const Duration(milliseconds: 1200);

  static const _storageKey = 'babyrelay.purchases.v1';

  final LocalStore _store;
  final Duration _actionDelay;

  bool _isPro = false;
  PlanId? _activePlan;
  DateTime? _trialEndsAt;
  bool _busy = false;
  String? _lastErrorMessage;

  /// What the next simulated store interaction does. Tests (and manual QA)
  /// flip this to exercise the cancel/failure paths the real store will hit.
  PurchaseOutcome nextPurchaseOutcome = PurchaseOutcome.success;
  bool failNextRestore = false;

  @override
  bool get isPro => _isPro;
  @override
  PlanId? get activePlan => _activePlan;
  @override
  DateTime? get trialEndsAt => _trialEndsAt;
  @override
  bool get busy => _busy;
  @override
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  List<Plan> get plans => const [
    Plan(
      id: PlanId.specialAnnual,
      productId: ProductIds.specialAnnual,
      title: 'Special annual',
      priceLabel: '\$29.99',
      periodLabel: 'per year',
      trialDays: 0,
      originalPriceLabel: '\$59.99',
      badge: 'Save 50%',
      subline: 'Limited family launch offer',
      isSpecialOffer: true,
    ),
    Plan(
      id: PlanId.annual,
      productId: ProductIds.annual,
      title: 'Annual',
      priceLabel: '\$59.99',
      periodLabel: 'per year',
      trialDays: 7,
      badge: '7-day trial',
      subline: 'About \$5 a month',
    ),
    Plan(
      id: PlanId.monthly,
      productId: ProductIds.monthly,
      title: 'Monthly',
      priceLabel: '\$9.99',
      periodLabel: 'per month',
      trialDays: 7,
    ),
  ];

  @override
  Future<void> load() async {
    final raw = await _store.read(_storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _isPro = json['isPro'] as bool? ?? false;
      _activePlan = json['plan'] == null
          ? null
          : PlanId.values.byName(json['plan'] as String);
      _trialEndsAt = json['trialEndsAt'] == null
          ? null
          : DateTime.parse(json['trialEndsAt'] as String);
      notifyListeners();
    } catch (_) {
      // A corrupt entitlement cache must never brick the app; the user can
      // always restore.
      _isPro = false;
      _activePlan = null;
      _trialEndsAt = null;
    }
  }

  Future<void> _persist() => _store.write(
    _storageKey,
    jsonEncode({
      'isPro': _isPro,
      'plan': _activePlan?.name,
      'trialEndsAt': _trialEndsAt?.toIso8601String(),
    }),
  );

  Future<T> _withBusy<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  Future<PurchaseOutcome> purchase(Plan plan) async {
    if (_busy) return PurchaseOutcome.failed;
    return _withBusy(() async {
      await Future<void>.delayed(_actionDelay);
      final outcome = nextPurchaseOutcome;
      nextPurchaseOutcome = PurchaseOutcome.success;
      switch (outcome) {
        case PurchaseOutcome.success:
          _isPro = true;
          _activePlan = plan.id;
          _trialEndsAt = plan.trialDays > 0
              ? DateTime.now().add(Duration(days: plan.trialDays))
              : null;
          _lastErrorMessage = null;
          await _persist();
          break;
        case PurchaseOutcome.cancelled:
          _lastErrorMessage = null;
          break;
        case PurchaseOutcome.failed:
          _lastErrorMessage =
              'The purchase could not be completed. '
              'You were not charged — please try again.';
          break;
      }
      return outcome;
    });
  }

  @override
  Future<RestoreOutcome> restore() async {
    if (_busy) return RestoreOutcome.failed;
    return _withBusy(() async {
      await Future<void>.delayed(_actionDelay);
      if (failNextRestore) {
        failNextRestore = false;
        _lastErrorMessage =
            'Could not reach the store to restore. Please try again.';
        return RestoreOutcome.failed;
      }
      // Locally there is nothing server-side; re-read the persisted
      // entitlement, which is what a reinstall would find.
      await load();
      _lastErrorMessage = null;
      return _isPro ? RestoreOutcome.restored : RestoreOutcome.nothingToRestore;
    });
  }

  /// Debug/QA escape hatch (Settings, debug builds only): drops back to the
  /// free tier so the paywall gates can be re-tested.
  Future<void> clearEntitlement() async {
    _isPro = false;
    _activePlan = null;
    _trialEndsAt = null;
    notifyListeners();
    await _persist();
  }
}
