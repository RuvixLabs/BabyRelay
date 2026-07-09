import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'purchase_service.dart';

class RevenueCatPurchaseService extends PurchaseService {
  RevenueCatPurchaseService({required this.apiKey, this.appUserId});

  final String apiKey;
  final String? appUserId;

  bool _configured = false;
  bool _isPro = false;
  PlanId? _activePlan;
  DateTime? _trialEndsAt;
  bool _busy = false;
  String? _lastErrorMessage;
  List<Plan> _plans = PurchaseService.fallbackPlans;
  final Map<PlanId, rc.Package> _packages = {};

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
  List<Plan> get plans => _plans;

  @override
  bool get inTrial =>
      _isPro && _trialEndsAt != null && DateTime.now().isBefore(_trialEndsAt!);

  @override
  Future<void> load() async {
    await _ensureConfigured();
    try {
      final info = await rc.Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 20),
      );
      _applyCustomerInfo(info);
      await _loadOfferings();
    } catch (error) {
      _lastErrorMessage =
          'Could not refresh subscription status. Please try again.';
      if (kDebugMode) debugPrint('[revenuecat] load failed: $error');
    }
    notifyListeners();
  }

  Future<void> _ensureConfigured() async {
    if (_configured || await rc.Purchases.isConfigured) {
      _configured = true;
      return;
    }
    if (kDebugMode) await rc.Purchases.setLogLevel(rc.LogLevel.debug);
    final configuration = rc.PurchasesConfiguration(apiKey)
      ..appUserID = appUserId;
    await rc.Purchases.configure(configuration);
    rc.Purchases.addCustomerInfoUpdateListener((info) {
      _applyCustomerInfo(info);
      notifyListeners();
    });
    _configured = true;
  }

  Future<void> _loadOfferings() async {
    final offerings = await rc.Purchases.getOfferings().timeout(
      const Duration(seconds: 20),
    );
    final byProduct = <String, rc.Package>{};
    for (final offering in [
      offerings.getOffering('special_offer'),
      offerings.current,
      ...offerings.all.values,
    ].whereType<rc.Offering>()) {
      for (final package in offering.availablePackages) {
        final identifier = package.storeProduct.identifier;
        byProduct[identifier] = package;
        final canonical = ProductIds.canonical(identifier);
        if (canonical != null) byProduct.putIfAbsent(canonical, () => package);
      }
    }

    _packages
      ..clear()
      ..addAll({
        for (final entry in ProductIds.byPlan.entries)
          if (byProduct[entry.value] != null)
            entry.key: byProduct[entry.value]!,
      });

    _plans = PurchaseService.fallbackPlans
        .map((plan) => _withStorePrice(plan, _packages[plan.id]))
        .toList();
  }

  Plan _withStorePrice(Plan fallback, rc.Package? package) {
    final product = package?.storeProduct;
    if (product == null) return fallback;
    return Plan(
      id: fallback.id,
      productId: product.identifier,
      title: fallback.title,
      priceLabel: product.priceString,
      periodLabel: fallback.periodLabel,
      trialDays: fallback.trialDays,
      originalPriceLabel: fallback.originalPriceLabel,
      countdownSeconds: fallback.countdownSeconds,
      badge: fallback.badge,
      subline: fallback.subline,
      isSpecialOffer: fallback.isSpecialOffer,
    );
  }

  void _applyCustomerInfo(rc.CustomerInfo info) {
    _isPro = info.entitlements.active.containsKey(
      PurchaseService.entitlementId,
    );
    final productId = info.activeSubscriptions.firstOrNull;
    _activePlan = ProductIds.planFor(productId);
    _trialEndsAt = null;
    _lastErrorMessage = null;
  }

  Future<T> _withBusy<T>(Future<T> Function() action) async {
    if (_busy) {
      _lastErrorMessage = 'A store request is already in progress.';
      notifyListeners();
      return Future<T>.error(StateError(_lastErrorMessage!));
    }
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
      await _ensureConfigured();
      final package = _packages[plan.id];
      if (package == null) {
        _lastErrorMessage =
            'This plan is not available from the store yet. Please try again soon.';
        return PurchaseOutcome.failed;
      }
      try {
        final result = await rc.Purchases.purchase(
          rc.PurchaseParams.package(package),
        ).timeout(const Duration(seconds: 60));
        _applyCustomerInfo(result.customerInfo);
        return PurchaseOutcome.success;
      } on PlatformException catch (error) {
        final code = rc.PurchasesErrorHelper.getErrorCode(error);
        if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
          _lastErrorMessage = null;
          return PurchaseOutcome.cancelled;
        }
        _lastErrorMessage = _messageForRevenueCatError(code);
        return PurchaseOutcome.failed;
      } catch (_) {
        _lastErrorMessage =
            'The purchase could not be completed. You were not charged — please try again.';
        return PurchaseOutcome.failed;
      }
    });
  }

  @override
  Future<RestoreOutcome> restore() async {
    if (_busy) return RestoreOutcome.failed;
    return _withBusy(() async {
      await _ensureConfigured();
      try {
        final info = await rc.Purchases.restorePurchases().timeout(
          const Duration(seconds: 45),
        );
        _applyCustomerInfo(info);
        return _isPro
            ? RestoreOutcome.restored
            : RestoreOutcome.nothingToRestore;
      } catch (_) {
        _lastErrorMessage =
            'Could not reach the store to restore. Please try again.';
        return RestoreOutcome.failed;
      }
    });
  }

  String _messageForRevenueCatError(rc.PurchasesErrorCode code) {
    switch (code) {
      case rc.PurchasesErrorCode.productNotAvailableForPurchaseError:
      case rc.PurchasesErrorCode.configurationError:
      case rc.PurchasesErrorCode.invalidCredentialsError:
        return 'This plan is not available from the store yet. Please try again soon.';
      case rc.PurchasesErrorCode.networkError:
      case rc.PurchasesErrorCode.offlineConnectionError:
        return 'The store could not be reached. Check your connection and try again.';
      default:
        return 'The purchase could not be completed. You were not charged — please try again.';
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
