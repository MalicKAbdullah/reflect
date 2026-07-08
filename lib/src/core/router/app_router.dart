import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/shell/home_shell.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/screens/setup_pin_screen.dart';
import 'package:reflect/src/features/auth/screens/unlock_screen.dart';
import 'package:reflect/src/features/calendar/screens/calendar_screen.dart';
import 'package:reflect/src/features/backup/screens/backup_screen.dart';
import 'package:reflect/src/features/entries/screens/entry_editor_screen.dart';
import 'package:reflect/src/features/entries/screens/entry_view_screen.dart';
import 'package:reflect/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:reflect/src/features/search/screens/search_screen.dart';
import 'package:reflect/src/features/settings/screens/change_pin_screen.dart';
import 'package:reflect/src/features/settings/screens/settings_screen.dart';
import 'package:reflect/src/features/stats/screens/stats_screen.dart';
import 'package:reflect/src/features/tags/screens/manage_tags_screen.dart';
import 'package:reflect/src/features/tags/screens/tag_timeline_screen.dart';
import 'package:reflect/src/features/timeline/screens/timeline_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String setup = '/setup';
  static const String unlock = '/unlock';
  static const String timeline = '/timeline';
  static const String calendar = '/calendar';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String newEntry = '/entry/new';
  static const String search = '/search';
  static const String changePin = '/change-pin';
  static const String backup = '/backup';
  static const String manageTags = '/tags';

  static String viewEntry(String id) => '/entry/$id';

  static String editEntry(String id) => '/entry/$id/edit';

  static String tagTimeline(String tag) => '/tag/${Uri.encodeComponent(tag)}';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..onDispose(refresh.dispose)
    ..listen(sessionProvider, (_, __) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionProvider);
      final location = state.matchedLocation;
      switch (status) {
        case AuthStatus.unknown:
          return AppRoutes.splash;
        case AuthStatus.needsOnboarding:
          return location == AppRoutes.welcome ? null : AppRoutes.welcome;
        case AuthStatus.needsSetup:
          return location == AppRoutes.setup ? null : AppRoutes.setup;
        case AuthStatus.locked:
          return location == AppRoutes.unlock ? null : AppRoutes.unlock;
        case AuthStatus.unlocked:
          final gate = location == AppRoutes.splash ||
              location == AppRoutes.welcome ||
              location == AppRoutes.setup ||
              location == AppRoutes.unlock;
          return gate ? AppRoutes.timeline : null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, __) => const SetupPinScreen(),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        builder: (_, __) => const UnlockScreen(),
      ),
      GoRoute(
        path: AppRoutes.newEntry,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const EntryEditorScreen(),
      ),
      GoRoute(
        path: '/entry/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            EntryViewScreen(entryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/entry/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            EntryEditorScreen(entryId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/tag/:tag',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => TagTimelineScreen(
          tag: Uri.decodeComponent(state.pathParameters['tag']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.manageTags,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const ManageTagsScreen(),
      ),
      GoRoute(
        path: AppRoutes.backup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const BackupScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePin,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const ChangePinScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.timeline,
                builder: (_, __) => const TimelineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (_, __) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (_, __) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
