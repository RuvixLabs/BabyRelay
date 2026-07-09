import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_chrome.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final tabsVisible = context.select<AppChromeController, bool>(
      (chrome) => chrome.tabsVisible,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: tabsVisible
            ? NavigationBar(
                key: const ValueKey('app-tabs'),
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    selectedIcon: Icon(Icons.wb_sunny),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.group_outlined),
                    selectedIcon: Icon(Icons.group),
                    label: 'Care team',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              )
            : const SizedBox(
                key: ValueKey('app-tabs-hidden'),
                height: 0,
                width: double.infinity,
              ),
      ),
    );
  }
}
