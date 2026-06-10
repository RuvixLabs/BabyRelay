import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_store.dart';

enum PlanId { monthly, annual }

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.periodLabel,
    required this.trialDays,
    this.badge,
    this.subline,
  });

  final PlanId id;
  final String title;
  final String priceLabel;
  final String periodLabel;
  final int trialDays;
  final String? badge;
  final String? subline;
}

enum PurchaseResult { success, cancelled, failed }

/// Mock of the RevenueCat-backed purchase layer.
///
/// Mirrors the surface the real integration will expose: an entitlement
/// (`pro`), offerings, purchase + restore, and trial state. Product IDs stay
/// out of business logic — screens only see [Plan]s and [isPro].
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._store);

  static const _storageKey = 'babyrelay.purchases.v1';
  static const entitlementId = 'pro';

  final LocalStore _store;

  bool _isPro = false;
  PlanId? _activePlan;
  DateTime? _trialEndsAt;
  bool _busy = false;

  bool get isPro => _isPro;
  PlanId? get activePlan => _activePlan;
  DateTime? get trialEndsAt => _trialEndsAt;
  bool get busy => _busy;

  bool get inTrial =>
      _isPro && _trialEndsAt != null && DateTime.now().isBefore(_trialEndsAt!);

  static const List<Plan> plans = [
    Plan(
      id: PlanId.annual,
      title: 'Annual',
      priceLabel: '\$59.99',
      periodLabel: 'per year',
      trialDays: 7,
      badge: 'Save 50%',
      subline: 'About \$5 a month',
    ),
    Plan(
      id: PlanId.monthly,
      title: 'Monthly',
      priceLabel: '\$9.99',
      periodLabel: 'per month',
      trialDays: 7,
    ),
  ];

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
      // Ignore corrupt purchase cache in the demo build.
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

  /// Simulates a StoreKit purchase with a trial start.
  Future<PurchaseResult> purchase(Plan plan) async {
    if (_busy) return PurchaseResult.failed;
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _isPro = true;
    _activePlan = plan.id;
    _trialEndsAt = DateTime.now().add(Duration(days: plan.trialDays));
    _busy = false;
    notifyListeners();
    await _persist();
    return PurchaseResult.success;
  }

  Future<bool> restore() async {
    if (_busy) return false;
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // The mock has nothing server-side to restore; reload local state.
    await load();
    _busy = false;
    notifyListeners();
    return _isPro;
  }

  /// Demo-only escape hatch in Settings.
  Future<void> clearEntitlement() async {
    _isPro = false;
    _activePlan = null;
    _trialEndsAt = null;
    notifyListeners();
    await _persist();
  }
}
