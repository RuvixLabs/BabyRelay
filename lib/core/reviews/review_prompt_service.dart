import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../data/local_store.dart';
import '../analytics/analytics_service.dart';

abstract final class ReviewPromptIds {
  static const trackingSuccess = 'tracking_success_v1';
  static const handoffSuccess = 'handoff_success_v1';
}

/// Versioned, local state for native review prompts.
///
/// Native store prompts are best-effort and rate-limited by the OS, so this
/// service only decides when BabyRelay should ask. The OS still decides whether
/// the native sheet actually appears.
class ReviewPromptService extends ChangeNotifier {
  ReviewPromptService(this._store, {bool enabled = true}) : _enabled = enabled;

  ReviewPromptService.disabled()
    : _store = InMemoryStore(),
      _enabled = false,
      _loaded = true;

  static const _storageKey = 'babyrelay.review_prompts.seen.v1';

  final LocalStore _store;
  final bool _enabled;
  final Set<String> _seen = {};
  bool _loaded = false;

  bool get enabled => _enabled;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (!_enabled) {
      _loaded = true;
      return;
    }
    final raw = await _store.read(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _seen
            ..clear()
            ..addAll(decoded.whereType<String>());
        }
      } on FormatException {
        _seen.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  bool shouldShow(String id) =>
      _enabled && _loaded && !_seen.contains(id) && _seen.isEmpty;

  Future<void> markSeen(String id) async {
    if (!_enabled) return;
    if (!_seen.add(id)) return;
    await _persist();
    notifyListeners();
  }

  Future<void> requestNativeReview(AnalyticsService analytics) async {
    if (!_enabled) return;
    try {
      final inAppReview = InAppReview.instance;
      final available = await inAppReview.isAvailable();
      analytics.logEvent('native_review_available', {'available': available});
      if (available) {
        await inAppReview.requestReview();
        analytics.logEvent('native_review_requested');
      }
    } catch (_) {
      analytics.logEvent('native_review_failed');
    }
  }

  Future<void> resetAll() async {
    if (!_enabled) return;
    _seen.clear();
    await _store.delete(_storageKey);
    notifyListeners();
  }

  Future<void> _persist() {
    final ids = _seen.toList()..sort();
    return _store.write(_storageKey, jsonEncode(ids));
  }
}
