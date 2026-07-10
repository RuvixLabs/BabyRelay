import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/family_repository.dart';
import '../features/care_team/care_team_screen.dart';
import '../features/handoff/handoff_screen.dart';
import '../features/join/join_family_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(FamilyRepository familyRepository) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    refreshListenable: familyRepository,
    redirect: (context, state) {
      final onboarded = familyRepository.state.onboarded;
      final onOnboarding = state.matchedLocation == '/onboarding';
      final onJoin = state.matchedLocation.startsWith('/join');
      if (!onboarded && !onOnboarding && !onJoin) return '/onboarding';
      if (onboarded && onOnboarding) return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinFamilyScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) =>
            JoinFamilyScreen(initialCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/handoff',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: HandoffScreen()),
      ),
      GoRoute(
        path: '/paywall',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: PaywallScreen(
            placement:
                state.uri.queryParameters['placement'] ?? 'settings_upgrade',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/team',
                builder: (context, state) => const CareTeamScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
