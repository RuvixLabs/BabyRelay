import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics_service.dart';
import '../core/design/relay_theme.dart';
import '../core/purchases/purchase_service.dart';
import '../data/family_repository.dart';
import 'router.dart';

class BabyRelayApp extends StatefulWidget {
  const BabyRelayApp({
    super.key,
    required this.familyRepository,
    required this.purchaseService,
    required this.analytics,
  });

  final FamilyRepository familyRepository;
  final PurchaseService purchaseService;
  final AnalyticsService analytics;

  @override
  State<BabyRelayApp> createState() => _BabyRelayAppState();
}

class _BabyRelayAppState extends State<BabyRelayApp> {
  late final router = buildRouter(widget.familyRepository);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.familyRepository),
        ChangeNotifierProvider.value(value: widget.purchaseService),
        Provider.value(value: widget.analytics),
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
