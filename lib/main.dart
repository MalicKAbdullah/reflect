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

  runApp(
    ProviderScope(
      overrides: [
        reminderSchedulerProvider.overrideWithValue(reminderScheduler),
      ],
      child: const ReflectApp(),
    ),
  );
}
