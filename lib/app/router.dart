import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/family_repository.dart';
import '../features/care_team/care_team_screen.dart';
import '../features/handoff/handoff_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/rating_request_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

GoRouter buildRouter(FamilyRepository familyRepository) {
  return GoRouter(
    initialLocation: '/today',
    refreshListenable: familyRepository,
    redirect: (context, state) {
      final onboarded = familyRepository.state.onboarded;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !onOnboarding) return '/onboarding';
      if (onboarded && onOnboarding) return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/rating-request',
        builder: (context, state) => const RatingRequestScreen(),
      ),
      GoRoute(
        path: '/handoff',
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: HandoffScreen()),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: PaywallScreen()),
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
