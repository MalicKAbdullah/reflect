import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/router/app_router.dart';

/// Post-unlock scaffold: bottom navigation plus a FAB for new entries.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      floatingActionButton: shell.currentIndex <= 1
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.newEntry),
              tooltip: 'New entry',
              child: const Icon(Icons.edit_outlined),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
