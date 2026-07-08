import 'dart:async';
import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reflect/src/core/app_info.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/providers/biometric_providers.dart';
import 'package:reflect/src/features/settings/providers/settings_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/reminders/providers/reminder_providers.dart';
import 'package:reflect/src/features/yearbook/services/year_book_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reflect/src/features/settings/widgets/goal_picker_sheet.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final autoLock = ref.watch(autoLockProvider);
    final biometricSupported =
        ref.watch(biometricSupportedProvider).valueOrNull ?? false;
    final biometricEnabled =
        ref.watch(biometricEnabledProvider).valueOrNull ?? false;
    final goal = ref.watch(writingGoalProvider);
    final reminder = ref.watch(dailyReminderProvider);
    final reminderTime = TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const _SectionLabel('Security'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            subtitle: const Text('Your journal is re-secured with it'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.changePin),
          ),
          if (biometricSupported)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric unlock'),
              subtitle:
                  const Text('Use fingerprint or face instead of your PIN'),
              value: biometricEnabled,
              onChanged: (next) => _toggleBiometrics(context, ref, next),
            ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-lock after'),
            subtitle: Text(AutoLockNotifier.labelFor(autoLock)),
            onTap: () => _pickAutoLock(context, ref, autoLock),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Lock now'),
            onTap: () => ref.read(sessionProvider.notifier).lock(),
          ),
          const Divider(height: AppSpacing.lg),
          const _SectionLabel('Journal'),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Daily writing goal'),
            subtitle: Text(goal?.description ?? 'Off'),
            onTap: () => showGoalPickerSheet(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Daily reminder'),
            subtitle: Text(
              reminder.enabled
                  ? 'Every day at ${reminderTime.format(context)}'
                  : 'A gentle nudge to write each evening',
            ),
            value: reminder.enabled,
            onChanged: (next) => _toggleReminder(context, ref, next),
          ),
          if (reminder.enabled)
            ListTile(
              leading: const SizedBox.shrink(),
              title: const Text('Reminder time'),
              subtitle: Text(reminderTime.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () => _pickReminderTime(context, ref, reminderTime),
            ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Tags'),
            subtitle: const Text('Browse, rename, or remove tags'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.manageTags),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Backup'),
            subtitle: const Text('Export or restore an encrypted backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.backup),
          ),
          ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('Export year book (PDF)'),
            subtitle: const Text('A year of entries as a beautiful PDF'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportYearBook(context, ref),
          ),
          const Divider(height: AppSpacing.lg),
          const _SectionLabel('Danger zone'),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: theme.colorScheme.error),
            title: Text(
              'Erase all data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text(
              'Permanently deletes your journal and PIN',
            ),
            onTap: () => _confirmErase(context, ref),
          ),
          const Divider(height: AppSpacing.lg),
          const _SectionLabel('About'),
          const ListTile(
            leading: Icon(Icons.self_improvement_rounded),
            title: Text('Reflect'),
            subtitle: Text('Version ${AppInfo.version}'),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Privacy'),
            subtitle: Text(AppInfo.privacyBlurb),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometrics(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final notifier = ref.read(biometricEnabledProvider.notifier);
    if (!enable) {
      await notifier.disable();
      return;
    }
    final ok = await notifier.enable();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric unlock could not be turned on'),
        ),
      );
    }
  }

  Future<void> _exportYearBook(BuildContext context, WidgetRef ref) async {
    final entries = ref.read(entriesProvider).valueOrNull ?? const [];
    final counts = <int, int>{};
    for (final entry in entries) {
      counts.update(entry.createdAt.year, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) {
      _snack(context, 'Write a few entries first — then export a year.');
      return;
    }
    final years = counts.keys.toList()..sort((a, b) => b.compareTo(a));

    final year = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Pick a year',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final y in years)
              ListTile(
                title: Text('$y'),
                subtitle: Text(
                  '${counts[y]} ${counts[y] == 1 ? 'entry' : 'entries'}',
                ),
                onTap: () => Navigator.of(context).pop(y),
              ),
          ],
        ),
      ),
    );
    if (year == null || !context.mounted) return;

    // Simple progress dialog while the PDF renders in an isolate.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Making your year book…')),
          ],
        ),
      ),
    ));

    try {
      final bytes = await YearBookPdfService.renderInBackground(
        year: year,
        entries: entries,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}'
        '${YearBookPdfService.suggestedFileName(year)}',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Progress.
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reflect — $year in review',
      );
      await file.delete();
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Progress.
        _snack(context, 'The year book could not be created');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final ok =
        await ref.read(dailyReminderProvider.notifier).setEnabled(enable);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are turned off for Reflect. '
            'Allow them in your device settings to get a daily reminder.',
          ),
        ),
      );
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Daily reminder time',
    );
    if (picked != null) {
      await ref
          .read(dailyReminderProvider.notifier)
          .setTime(hour: picked.hour, minute: picked.minute);
    }
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    Duration current,
  ) async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in AutoLockNotifier.options)
              ListTile(
                title: Text(AutoLockNotifier.labelFor(option)),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await ref.read(autoLockProvider.notifier).setTimeout(choice);
    }
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'Your journal, PIN and settings will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).eraseAll();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style:
            Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 1),
      ),
    );
  }
}
