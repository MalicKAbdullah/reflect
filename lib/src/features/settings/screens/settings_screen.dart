import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_backup/core_backup.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reflect/src/core/app_info.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/widgets/confirm_owner.dart';
import 'package:reflect/src/features/auth/providers/biometric_providers.dart';
import 'package:reflect/src/features/settings/providers/settings_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/reminders/providers/reminder_providers.dart';
import 'package:reflect/src/features/yearbook/services/year_book_pdf_service.dart';
import 'package:reflect/src/features/yearbook/services/year_book_photo_loader.dart';
import 'package:reflect/src/features/yearbook/widgets/year_book_export_sheet.dart';
import 'package:reflect/src/core/di.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reflect/src/features/settings/widgets/goal_picker_sheet.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SuiteColors.of(context);
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
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Settings',
              style: AppTextStyles.h2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            RowGroup(
              children: [
                AppearanceSetting(controller: ref.watch(appearanceProvider)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Security'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.password_outlined,
                  title: 'Change password',
                  subtitle: 'Your journal is re-secured with it',
                  onTap: () => context.push(AppRoutes.changePin),
                ),
                SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'Recovery key',
                  subtitle: 'Resets a forgotten password',
                  onTap: () => _newRecoveryKey(context, ref),
                ),
                if (biometricSupported)
                  SettingsTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'Fingerprint unlock',
                    subtitle: 'Use a fingerprint instead of your password',
                    trailing: Switch(
                      value: biometricEnabled,
                      onChanged: (next) =>
                          _toggleBiometrics(context, ref, next),
                    ),
                  ),
                SettingsTile(
                  icon: Icons.timer_outlined,
                  title: 'Auto-lock after',
                  subtitle: AutoLockNotifier.labelFor(autoLock),
                  onTap: () => _pickAutoLock(context, ref, autoLock),
                ),
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Lock now',
                  onTap: () => ref.read(sessionProvider.notifier).lock(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Updates'),
            const _UpdateSection(),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Journal'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.flag_outlined,
                  title: 'Daily writing goal',
                  subtitle: goal?.description ?? 'Off',
                  onTap: () => showGoalPickerSheet(context, ref),
                ),
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Daily reminder',
                  subtitle: reminder.enabled
                      ? 'Every day at ${reminderTime.format(context)}'
                      : 'A nudge to write each evening',
                  trailing: Switch(
                    value: reminder.enabled,
                    onChanged: (next) => _toggleReminder(context, ref, next),
                  ),
                ),
                if (reminder.enabled)
                  SettingsTile(
                    icon: Icons.schedule_outlined,
                    title: 'Reminder time',
                    subtitle: reminderTime.format(context),
                    onTap: () => _pickReminderTime(context, ref, reminderTime),
                  ),
                SettingsTile(
                  icon: Icons.label_outline,
                  title: 'Tags',
                  subtitle: 'Browse, rename, or remove tags',
                  onTap: () => context.push(AppRoutes.manageTags),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Backup and export'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.archive_outlined,
                  title: 'Backup',
                  subtitle: 'Export or restore an encrypted backup',
                  onTap: () => context.push(AppRoutes.backup),
                ),
                SettingsTile(
                  icon: Icons.auto_stories_outlined,
                  title: 'Export year book (PDF)',
                  subtitle: 'A year of entries as a beautiful PDF',
                  onTap: () => _exportYearBook(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Automatic backup'),
            AutoBackupSection(
              service: ref.watch(autoBackupServiceProvider),
              producer: ref.watch(reflectBackupProducerProvider),
              onRevealGate: () => confirmOwner(
                context,
                ref,
                reason: 'Show your backup passphrase',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Danger zone'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  iconColor: c.negative,
                  title: 'Erase all data',
                  subtitle: 'Deletes your journal and password',
                  onTap: () => _confirmErase(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'About'),
            RowGroup(
              children: [
                SettingsTile(
                  icon: Icons.self_improvement_rounded,
                  title: 'Reflect',
                  subtitle:
                      'Version ${ref.watch(appVersionProvider).valueOrNull ?? ''}',
                ),
                const SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy',
                  subtitle: AppInfo.privacyBlurb,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Center(child: SuiteEndorsement()),
          ],
        ),
      ),
    );
  }

  /// Re-auth, confirm replacing any current key, then show the new one.
  Future<void> _newRecoveryKey(BuildContext context, WidgetRef ref) async {
    if (!await confirmOwner(context, ref,
        reason: 'Create a new recovery key')) {
      return;
    }
    if (await ref.read(pinAuthServiceProvider).hasRecoveryKey()) {
      if (!context.mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace your recovery key?'),
          content: const Text(
            'Your current recovery key will stop working. Recovery keys are '
            'never stored, so the current one cannot be shown again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create new key'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    final key = await ref.read(sessionProvider.notifier).createRecoveryKey();
    if (context.mounted) {
      await context.push(AppRoutes.recoveryKey, extra: key);
    }
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

    final choice = await showYearBookExportSheet(
      context: context,
      years: years,
      counts: counts,
    );
    if (choice == null || !context.mounted) return;
    final year = choice.year;

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
      // Photos are AES-encrypted on disk; decrypt them here (main isolate,
      // with the session key) before the render runs off-thread.
      final photos = choice.includePhotos
          ? await loadYearBookPhotos(
              service: ref.read(attachmentServiceProvider),
              key: ref.read(sessionProvider.notifier).dataKey,
              entries: entries,
              year: year,
              maxPerEntry: YearBookPdfService.maxPhotosPerEntry,
            )
          : const <String, Uint8List>{};
      final bytes = await YearBookPdfService.renderInBackground(
        year: year,
        entries: entries,
        photos: photos,
        includePhotos: choice.includePhotos,
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
          'Your journal, password and settings will be permanently deleted. '
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

/// "Check for updates on open" toggle + a manual "Check now", backed by
/// core_update. On by default; the only network call the app makes.
class _UpdateSection extends ConsumerStatefulWidget {
  const _UpdateSection();

  @override
  ConsumerState<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<_UpdateSection> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You're on the latest version.")),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update available · v${info.version}'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () => ref.read(updateServiceProvider).openDownload(info),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoCheck = ref.watch(updateAutoCheckProvider).valueOrNull ?? true;
    return RowGroup(
      children: [
        SettingsTile(
          icon: Icons.system_update_alt,
          title: 'Check for updates',
          subtitle: 'Checks GitHub on open',
          trailing: Switch(
            value: autoCheck,
            onChanged: (v) async {
              await ref.read(secureStorageProvider).write(
                    key: updateAutoCheckKey,
                    value: v ? 'true' : 'false',
                  );
              ref.invalidate(updateAutoCheckProvider);
              ref.invalidate(updateCheckProvider);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.refresh,
          title: 'Check now',
          trailing: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _checking ? null : _checkNow,
        ),
      ],
    );
  }
}
