import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/purchases/purchase_service.dart';
import 'data/family_repository.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Local-first build: everything persists on-device. Firebase (Auth/
  // Firestore/Analytics/Crashlytics/Messaging), RevenueCat, AppRefer, and
  // Gleap initialize here once their credentials arrive via --dart-define —
  // see lib/core/config/app_config.dart and docs/production-readiness.md.
  final store = await SharedPrefsStore.create();
  final familyRepository = FamilyRepository(store);
  final PurchaseService purchaseService = LocalPurchaseService(store);
  await Future.wait([familyRepository.load(), purchaseService.load()]);

  runApp(
    BabyRelayApp(
      familyRepository: familyRepository,
      purchaseService: purchaseService,
      analytics: AnalyticsService(),
    ),
  );
}
