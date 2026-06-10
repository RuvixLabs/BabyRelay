import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key-value persistence boundary. The app uses SharedPreferences; tests
/// use [InMemoryStore]. When Firebase lands, repositories swap this for
/// Firestore-backed implementations without UI changes.
abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPrefsStore implements LocalStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsStore> create() async =>
      SharedPrefsStore(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> delete(String key) => _prefs.remove(key);
}

class InMemoryStore implements LocalStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
