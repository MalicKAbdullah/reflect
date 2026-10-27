import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/app.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/reminders/services/local_notification_reminder_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-backed reminder scheduling; tests keep the no-op default.
  final reminderScheduler = LocalNotificationReminderScheduler();
  await reminderScheduler.initialize();
  final appearance = await AppearanceController.load();

  runApp(
    ProviderScope(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(reminderScheduler),
        appearanceProvider.overrideWithValue(appearance),
      ],
      child: const ReflectApp(),
    ),
  );
}
