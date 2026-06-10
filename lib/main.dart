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

  // Demo build: local persistence only. Firebase (Auth/Firestore/Analytics/
  // Crashlytics/Messaging), RevenueCat, AppRefer, and Gleap initialize here
  // once credentials exist — see Settings > Integrations.
  final store = await SharedPrefsStore.create();
  final familyRepository = FamilyRepository(store);
  final purchaseService = PurchaseService(store);
  await Future.wait([familyRepository.load(), purchaseService.load()]);

  runApp(
    BabyRelayApp(
      familyRepository: familyRepository,
      purchaseService: purchaseService,
      analytics: AnalyticsService(),
    ),
  );
}
