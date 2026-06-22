import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_store.dart';

abstract final class TutorialIds {
  static const todayIntro = 'today_intro_v1';
  static const childSwitcher = 'child_switcher_v1';
  static const handoff = 'handoff_v1';
  static const careTeam = 'care_team_v1';
}

/// Versioned, local tutorial state. Each id is intentionally explicit so a
/// future UI redesign can introduce `*_v2` without resurfacing old hints.
class TutorialService extends ChangeNotifier {
  TutorialService(this._store, {bool enabled = true}) : _enabled = enabled;

  TutorialService.disabled()
    : _store = InMemoryStore(),
      _enabled = false,
      _loaded = true;

  static const _storageKey = 'babyrelay.tutorials.seen.v1';

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

  bool shouldShow(String id) => _enabled && _loaded && !_seen.contains(id);

  void requestVisibleTutorialCheck() {
    if (_enabled) notifyListeners();
  }

  Future<void> markSeen(String id) async {
    if (!_enabled) return;
    if (!_seen.add(id)) return;
    await _persist();
    notifyListeners();
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
