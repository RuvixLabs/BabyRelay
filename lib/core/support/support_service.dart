import 'package:flutter/foundation.dart';
import 'package:gleap_sdk/gleap_sdk.dart';

class SupportService {
  SupportService._({required this.configured});

  final bool configured;

  factory SupportService.disabled() => SupportService._(configured: false);

  static Future<SupportService> create({required String gleapSdkKey}) async {
    if (gleapSdkKey.isEmpty) return SupportService._(configured: false);
    try {
      await Gleap.initialize(token: gleapSdkKey);
      await Gleap.setActivationMethods(
        activationMethods: const <ActivationMethod>[],
      );
      return SupportService._(configured: true);
    } catch (error) {
      if (kDebugMode) debugPrint('[gleap] initialize failed: $error');
      return SupportService._(configured: false);
    }
  }

  Future<bool> openConversation({String? userId}) async {
    if (!configured) return false;
    try {
      if (userId != null && userId.isNotEmpty) {
        await Gleap.identifyContact(userId: userId);
      }
      await Gleap.startConversation(showBackButton: true);
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('[gleap] open conversation failed: $error');
      return false;
    }
  }
}
