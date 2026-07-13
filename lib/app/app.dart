import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics/analytics_service.dart';
import '../core/attribution/attribution_service.dart';
import '../core/design/relay_theme.dart';
import '../core/purchases/purchase_service.dart';
import '../core/reviews/review_prompt_service.dart';
import '../core/sleep/sleep_runtime_service.dart';
import '../core/support/support_service.dart';
import '../core/tutorial/tutorial_service.dart';
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
    required this.tutorialService,
    required this.reviewPromptService,
    this.sleepRuntimeService,
  });

  final FamilyRepository familyRepository;
  final PurchaseService purchaseService;
  final AnalyticsService analytics;
  final SupportService supportService;
  final AttributionService attributionService;
  final TutorialService tutorialService;
  final ReviewPromptService reviewPromptService;
  final SleepRuntimeService? sleepRuntimeService;

  @override
  State<BabyRelayApp> createState() => _BabyRelayAppState();
}

class _BabyRelayAppState extends State<BabyRelayApp> {
  late final appChrome = AppChromeController();
  late final router = buildRouter(widget.familyRepository);
  late final sleepRuntimeService =
      widget.sleepRuntimeService ?? SleepRuntimeService.disabled();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeAttribution());
    });
  }

  Future<void> _initializeAttribution() async {
    final deferredInviteCode = await widget.attributionService
        .initializeAfterFirstFrame();
    if (!mounted || deferredInviteCode == null) return;

    final currentPathSegments =
        router.routeInformationProvider.value.uri.pathSegments;
    final hasExplicitJoinCode =
        currentPathSegments.length >= 2 &&
        currentPathSegments.first == 'join' &&
        currentPathSegments[1].isNotEmpty;
    if (widget.familyRepository.state.onboarded || hasExplicitJoinCode) {
      await widget.attributionService.consumePendingInviteCode();
      return;
    }
    router.go('/join/$deferredInviteCode');
  }

  @override
  void dispose() {
    appChrome.dispose();
    unawaited(sleepRuntimeService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appChrome),
        ChangeNotifierProvider.value(value: widget.familyRepository),
        ChangeNotifierProvider.value(value: widget.purchaseService),
        ChangeNotifierProvider.value(value: widget.tutorialService),
        ChangeNotifierProvider.value(value: widget.reviewPromptService),
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
