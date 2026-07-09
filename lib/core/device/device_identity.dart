import 'dart:math';

import '../../data/local_store.dart';

abstract final class DeviceIdentity {
  static const _storageKey = 'babyrelay.device_id.v1';
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static Future<String> getOrCreate(LocalStore store) async {
    final existing = await store.read(_storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final suffix = List.generate(
      24,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
    final deviceId = 'd_${DateTime.now().microsecondsSinceEpoch}_$suffix';
    await store.write(_storageKey, deviceId);
    return deviceId;
  }
}
