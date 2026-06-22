import 'package:flutter/foundation.dart';

/// Privacy-safe analytics wrapper.
///
/// Hard rules for this app (child/family data):
/// - Only allowlisted, stable event names are ever sent.
/// - No baby names, caregiver names, free text, or health details in params.
/// - Params are limited to small enums/counters declared at the call site.
///
/// In the local-first build events go to debug logs; the Firebase Analytics
/// implementation plugs in behind this same interface later.
class AnalyticsService {
  AnalyticsService();

  static const Set<String> _allowedEvents = {
    'onboarding_started',
    'onboarding_step_viewed',
    'onboarding_completed',
    'onboarding_rating_viewed',
    'onboarding_rating_positive',
    'onboarding_rating_skipped',
    'native_review_available',
    'native_review_requested',
    'native_review_failed',
    'baby_profile_created',
    'child_added',
    'child_switched',
    'child_removed',
    'child_profile_edited',
    'care_event_logged',
    'care_event_edited',
    'care_event_deleted',
    'care_events_merged',
    'next_up_viewed',
    'handoff_opened',
    'handoff_shared',
    'caregiver_invite_started',
    'caregiver_invite_sent',
    'caregiver_joined',
    'caregiver_removed',
    'notification_enabled',
    'notification_tapped',
    'paywall_viewed',
    'plan_selected',
    'purchase_started',
    'purchase_completed',
    'purchase_cancelled',
    'purchase_failed',
    'support_contacted',
    'restore_tapped',
    'restore_completed',
    'restore_empty',
    'restore_failed',
    'sample_day_loaded',
    'data_deleted',
    'coach_mark_seen',
    'coach_mark_skipped',
    'coach_mark_completed',
  };

  void logEvent(String name, [Map<String, Object>? params]) {
    assert(
      _allowedEvents.contains(name),
      'Analytics event "$name" is not in the allowlist.',
    );
    if (!_allowedEvents.contains(name)) return;
    assert(
      _paramsAreSafe(params),
      'Analytics params must be enum/number-like.',
    );
    if (kDebugMode) {
      debugPrint('[analytics] $name ${params ?? {}}');
    }
    sendEvent(name, params);
  }

  @protected
  void sendEvent(String name, Map<String, Object>? params) {}

  bool _paramsAreSafe(Map<String, Object>? params) {
    if (params == null) return true;
    for (final value in params.values) {
      if (value is num || value is bool) continue;
      // Strings must look like short enum tokens, never free text.
      if (value is String && value.length <= 24 && !value.contains(' ')) {
        continue;
      }
      return false;
    }
    return true;
  }
}
