import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics_service.dart';
import '../core/attribution/attribution_service.dart';
import '../core/design/relay_theme.dart';
import '../core/purchases/purchase_service.dart';
import '../core/support/support_service.dart';
import '../data/family_repository.dart';
import 'app_chrome.dart';
import 'router.dart';

class BabyRelayApp extends StatefulWidget {
  const BabyRelayApp({
    super.key,
    required this.familyRepository,
    required this.purchaseService,
    required this.analytics,
    required this.supportService,
    required this.attributionService,
  });

  final FamilyRepository familyRepository;
  final PurchaseService purchaseService;
  final AnalyticsService analytics;
  final SupportService supportService;
  final AttributionService attributionService;

  @override
  State<BabyRelayApp> createState() => _BabyRelayAppState();
}

class _BabyRelayAppState extends State<BabyRelayApp> {
  late final appChrome = AppChromeController();
  late final router = buildRouter(widget.familyRepository);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.attributionService.requestTrackingAuthorizationIfNeeded();
    });
  }

  @override
  void dispose() {
    appChrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appChrome),
        ChangeNotifierProvider.value(value: widget.familyRepository),
        ChangeNotifierProvider.value(value: widget.purchaseService),
        Provider.value(value: widget.analytics),
        Provider.value(value: widget.supportService),
        Provider.value(value: widget.attributionService),
      ],
      child: MaterialApp.router(
        title: 'BabyRelay',
        debugShowCheckedModeBanner: false,
        theme: RelayTheme.light(),
        darkTheme: RelayTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
