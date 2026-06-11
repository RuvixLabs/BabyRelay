import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class AttributionService {
  AttributionService({required this.configured});

  final bool configured;
  bool _requested = false;

  Future<void> requestTrackingAuthorizationIfNeeded() async {
    if (!configured || _requested) return;
    _requested = true;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[attribution] ATT request failed: $error');
    }
  }
}
