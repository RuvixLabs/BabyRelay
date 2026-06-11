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
import 'core/purchases/purchase_service.dart';
import 'core/purchases/revenuecat_purchase_service.dart';
import 'core/support/support_service.dart';
import 'data/firestore_family_sync.dart';
import 'data/family_repository.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = await SharedPrefsStore.create();
  final familyRepository = FamilyRepository(store);
  AnalyticsService analytics = AnalyticsService();
  await familyRepository.load();

  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp();
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

  final PurchaseService purchaseService = AppConfig.revenueCatApiKey.isEmpty
      ? LocalPurchaseService(store)
      : RevenueCatPurchaseService(
          apiKey: AppConfig.revenueCatApiKey,
          appUserId: familyRepository.syncUserId,
        );
  await purchaseService.load();
  final supportService = await SupportService.create(
    gleapSdkKey: AppConfig.gleapSdkKey,
  );
  final attributionService = AttributionService(
    configured: AppConfig.appReferLinkId.isNotEmpty,
  );

  runApp(
    BabyRelayApp(
      familyRepository: familyRepository,
      purchaseService: purchaseService,
      analytics: analytics,
      supportService: supportService,
      attributionService: attributionService,
    ),
  );
}
