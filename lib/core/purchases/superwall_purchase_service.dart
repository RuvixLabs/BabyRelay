import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart' as sw;

import 'purchase_service.dart';

/// Superwall-primary subscription service.
///
/// No custom purchase controller is supplied: Superwall owns StoreKit / Play
/// Billing purchases, restores, receipt state, and remote paywall presentation.
class SuperwallPurchaseService extends PurchaseService {
  SuperwallPurchaseService({required this.apiKey, required this.appUserId});

  final String apiKey;
  final String appUserId;

  StreamSubscription<sw.SubscriptionStatus>? _statusSubscription;
  Completer<void>? _configurationReady;
  bool _configurationStarted = false;
  bool _configured = false;
  bool _isPro = false;
  PlanId? _activePlan;
  DateTime? _trialEndsAt;
  bool _busy = false;
  String? _lastErrorMessage;

  @override
  bool get usesRemotePaywalls => true;
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
  List<Plan> get plans => PurchaseService.fallbackPlans;

  @override
  Future<void> load() async {
    if (_configured) {
      unawaited(_refreshSubscriptionState());
      return;
    }
    if (_configurationStarted) return;

    _configurationStarted = true;
    _configurationReady = Completer<void>();
    final configured = Completer<void>();
    sw.Superwall.configure(
      apiKey,
      completion: () {
        if (!configured.isCompleted) configured.complete();
      },
    );
    _statusSubscription = sw.Superwall.shared.subscriptionStatus.listen(
      (status) {
        _applySubscriptionStatus(status);
        unawaited(_refreshCustomerDetails());
      },
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) debugPrint('[superwall] status stream failed: $error');
      },
    );

    unawaited(_finishConfiguration(configured.future));
  }

  Future<void> _finishConfiguration(Future<void> configured) async {
    try {
      await configured.timeout(const Duration(seconds: 20));
      if (appUserId.isNotEmpty) {
        await sw.Superwall.shared.identify(appUserId);
      }
      _configured = true;
      await _refreshSubscriptionState();
    } catch (error) {
      _lastErrorMessage =
          'Could not refresh subscription status. Please try again.';
      if (kDebugMode) debugPrint('[superwall] configuration failed: $error');
      notifyListeners();
    } finally {
      if (!(_configurationReady?.isCompleted ?? true)) {
        _configurationReady!.complete();
      }
    }
  }

  Future<bool> _waitUntilConfigured() async {
    await load();
    try {
      await _configurationReady?.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      _lastErrorMessage =
          'The subscription service took too long to start. Please try again.';
    }
    return _configured;
  }

  Future<void> _refreshSubscriptionState() async {
    final status = await sw.Superwall.shared.getSubscriptionStatus().timeout(
      const Duration(seconds: 20),
    );
    _applySubscriptionStatus(status);
    await _refreshCustomerDetails();
  }

  void _applySubscriptionStatus(sw.SubscriptionStatus status) {
    final isPro =
        status is sw.SubscriptionStatusActive &&
        status.entitlements.any(
          (entitlement) => entitlement.id == PurchaseService.entitlementId,
        );
    final changed = _isPro != isPro;
    _isPro = isPro;
    if (!isPro) {
      _activePlan = null;
      _trialEndsAt = null;
    }
    _lastErrorMessage = null;
    if (changed) notifyListeners();
  }

  Future<void> _refreshCustomerDetails() async {
    try {
      final info = await sw.Superwall.shared.getCustomerInfo().timeout(
        const Duration(seconds: 20),
      );
      sw.SubscriptionTransaction? activeSubscription;
      for (final subscription in info.subscriptions) {
        if (subscription.isActive) {
          activeSubscription = subscription;
          break;
        }
      }
      final nextPlan = ProductIds.planFor(activeSubscription?.productId);
      final nextTrialEnd =
          activeSubscription?.offerType == sw.LatestSubscriptionOfferType.trial
          ? activeSubscription?.expirationDate
          : null;
      final changed = nextPlan != _activePlan || nextTrialEnd != _trialEndsAt;
      _activePlan = nextPlan;
      _trialEndsAt = nextTrialEnd;
      if (changed) notifyListeners();
    } catch (error) {
      // Entitlement state is authoritative. Extra plan/trial metadata is best
      // effort and must not turn an active subscriber into a free user.
      if (kDebugMode) {
        debugPrint('[superwall] customer detail refresh failed: $error');
      }
    }
  }

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
  Future<PaywallOutcome> presentPaywall(
    String placement, {
    Map<String, Object>? params,
  }) async {
    if (_busy) return PaywallOutcome.failed;
    return _withBusy(() async {
      if (!await _waitUntilConfigured()) return PaywallOutcome.failed;
      final outcome = Completer<PaywallOutcome>();
      void complete(PaywallOutcome value) {
        if (!outcome.isCompleted) outcome.complete(value);
      }

      final handler = sw.PaywallPresentationHandler()
        ..onDismiss((_, result) async {
          try {
            await _refreshSubscriptionState();
          } catch (error) {
            _lastErrorMessage =
                'Could not refresh subscription status. Please try again.';
            if (kDebugMode) {
              debugPrint('[superwall] post-paywall refresh failed: $error');
            }
          }
          switch (result) {
            case sw.PurchasedPaywallResult():
              complete(
                _isPro ? PaywallOutcome.purchased : PaywallOutcome.failed,
              );
            case sw.RestoredPaywallResult():
              complete(
                _isPro ? PaywallOutcome.restored : PaywallOutcome.failed,
              );
            case sw.DeclinedPaywallResult():
              complete(PaywallOutcome.dismissed);
          }
        })
        ..onError((error) {
          _lastErrorMessage =
              'The paywall could not be loaded. Check your connection and try again.';
          if (kDebugMode) debugPrint('[superwall] paywall failed: $error');
          complete(PaywallOutcome.failed);
        })
        ..onSkip((_) => complete(PaywallOutcome.skipped));

      try {
        await sw.Superwall.shared.registerPlacement(
          placement,
          params: params,
          handler: handler,
          feature: () => complete(PaywallOutcome.skipped),
        );
        return await outcome.future.timeout(const Duration(minutes: 5));
      } on TimeoutException {
        _lastErrorMessage =
            'The paywall took too long to respond. Please try again.';
        return PaywallOutcome.failed;
      } catch (error) {
        _lastErrorMessage =
            'The paywall could not be loaded. Check your connection and try again.';
        if (kDebugMode) debugPrint('[superwall] placement failed: $error');
        return PaywallOutcome.failed;
      }
    });
  }

  @override
  Future<PurchaseOutcome> purchase(Plan plan) async {
    _lastErrorMessage =
        'Purchases are presented through the secure Superwall paywall.';
    return PurchaseOutcome.failed;
  }

  @override
  Future<RestoreOutcome> restore() async {
    if (_busy) return RestoreOutcome.failed;
    return _withBusy(() async {
      if (!await _waitUntilConfigured()) return RestoreOutcome.failed;
      try {
        final result = await sw.Superwall.shared.restorePurchases().timeout(
          const Duration(seconds: 45),
        );
        if (result is sw.RestorationResultFailed) {
          _lastErrorMessage =
              'Could not reach the store to restore. Please try again.';
          return RestoreOutcome.failed;
        }
        await _refreshSubscriptionState();
        return _isPro
            ? RestoreOutcome.restored
            : RestoreOutcome.nothingToRestore;
      } catch (error) {
        _lastErrorMessage =
            'Could not reach the store to restore. Please try again.';
        if (kDebugMode) debugPrint('[superwall] restore failed: $error');
        return RestoreOutcome.failed;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_statusSubscription?.cancel());
    super.dispose();
  }
}
