import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/core/security/inactivity_locker.dart';
import 'package:reflect/src/features/reminders/providers/reminder_providers.dart';

class ReflectApp extends ConsumerWidget {
  const ReflectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Touch the reminder provider so a stored daily reminder is
    // rescheduled on every app start.
    ref.watch(dailyReminderProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Reflect',
      theme: AppTheme.build(Brightness.light, accent: AppColors.violetAccent),
      darkTheme:
          AppTheme.build(Brightness.dark, accent: AppColors.violetAccent),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          InactivityLocker(child: child ?? const SizedBox.shrink()),
    );
  }
}
