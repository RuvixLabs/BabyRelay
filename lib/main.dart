import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/attribution/attribution_service.dart';
import 'core/config/app_config.dart';
import 'core/device/device_identity.dart';
import 'core/purchases/purchase_service.dart';
import 'core/purchases/superwall_purchase_service.dart';
import 'core/reviews/review_prompt_service.dart';
import 'core/sleep/sleep_remote_message_handler.dart';
import 'core/sleep/sleep_remote_sync_service.dart';
import 'core/sleep/sleep_runtime_service.dart';
import 'core/support/support_service.dart';
import 'core/tutorial/tutorial_service.dart';
import 'data/firestore_family_sync.dart';
import 'data/family_repository.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validateReleaseConfiguration();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = await SharedPrefsStore.create();
  final deviceId = await DeviceIdentity.getOrCreate(store);
  final familyRepository = FamilyRepository(store, deviceId: deviceId);
  final tutorialService = TutorialService(store);
  final reviewPromptService = ReviewPromptService(store);
  AnalyticsService analytics = AnalyticsService();
  await familyRepository.load();
  await tutorialService.load();
  await reviewPromptService.load();

  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        babyRelayFirebaseMessagingBackgroundHandler,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      analytics = FirebaseAnalyticsService(FirebaseAnalytics.instance);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final sync = await FirestoreFamilySyncAdapter.create();
      await familyRepository.attachSync(sync);
      await SleepRemoteSyncService.create(
        familyRepository: familyRepository,
        deviceId: deviceId,
      );
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'BabyRelay startup',
          context: ErrorDescription('initializing Firebase services'),
        ),
      );
    }
  }

  final PurchaseService purchaseService = AppConfig.superwallApiKey.isEmpty
      ? LocalPurchaseService(store)
      : SuperwallPurchaseService(
          apiKey: AppConfig.superwallApiKey,
          appUserId: familyRepository.syncUserId ?? '',
        );
  await purchaseService.load();
  void syncFamilyEntitlement() {
    if (purchaseService.isPro && familyRepository.state.onboarded) {
      unawaited(
        familyRepository.setFamilySubscriptionStatus(
          active: true,
          planId: purchaseService.activePlan?.name ?? '',
        ),
      );
    }
  }

  purchaseService.addListener(syncFamilyEntitlement);
  syncFamilyEntitlement();
  final supportService = await SupportService.create(
    gleapSdkKey: AppConfig.gleapSdkKey,
  );
  final attributionService = AttributionService(
    apiKey: AppConfig.appReferApiKey,
    userId: familyRepository.syncUserId ?? '',
  );
  final sleepRuntimeService = await SleepRuntimeService.create(
    familyRepository: familyRepository,
    analytics: analytics,
  );

  runApp(
    BabyRelayApp(
      familyRepository: familyRepository,
      purchaseService: purchaseService,
      analytics: analytics,
      supportService: supportService,
      attributionService: attributionService,
      tutorialService: tutorialService,
      reviewPromptService: reviewPromptService,
      sleepRuntimeService: sleepRuntimeService,
    ),
  );
}
