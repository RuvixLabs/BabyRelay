import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_service.dart';

class FirebaseAnalyticsService extends AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void sendEvent(String name, Map<String, Object>? params) {
    _analytics.logEvent(name: name, parameters: params);
  }
}
