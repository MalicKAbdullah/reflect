import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/backup/services/backup_service.dart';
import 'package:reflect/src/features/backup/widgets/import_preview_dialog.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:share_plus/share_plus.dart';

/// Encrypted backup: export the journal as a passphrase-protected
/// `.rfbackup` file, or restore one (merge or replace).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _exportError;
  bool _exporting = false;
  bool _importing = false;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final passphrase = _passphraseController.text;
    if (passphrase.length < BackupService.minPassphraseLength) {
      setState(() => _exportError =
          'Use at least ${BackupService.minPassphraseLength} characters');
      return;
    }
    if (passphrase != _confirmController.text) {
      setState(() => _exportError = 'Passphrases do not match');
      return;
    }
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final entries = await ref.read(entriesProvider.future);
      final session = ref.read(sessionProvider.notifier);
      // Photos travel inside the backup: decrypt each attachment so it can
      // be re-encrypted under the backup passphrase.
      final attachments =
          await ref.read(attachmentServiceProvider).exportPlaintext(
        ids: {for (final e in entries) ...e.photoIds},
        key: session.dataKey,
      );
      final service = ref.read(backupServiceProvider);
      final json = await service.export(
        entries: entries,
        passphrase: passphrase,
        attachments: attachments,
      );
      if (json.length > BackupService.largeBackupBytes && mounted) {
        final proceed = await _confirmLargeBackup(json.length);
        if (proceed != true) return;
      }
      if (!mounted) return;
      final dir = await getTemporaryDirectory();
      final name = BackupService.suggestedFileName(
        ref.read(clockProvider).now(),
      );
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsString(json, flush: true);
      await Share.shareXFiles([XFile(file.path)], subject: 'Reflect backup');
      await file.delete();
      if (mounted) {
        _passphraseController.clear();
        _confirmController.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _exportError = 'Could not create the backup');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.platform.pickFiles();
      final path = picked?.files.single.path;
      if (path == null) return;
      final raw = await File(path).readAsString();
      if (!mounted) return;

      final passphrase = await promptBackupPassphrase(context);
      if (passphrase == null || passphrase.isEmpty || !mounted) return;

      final service = ref.read(backupServiceProvider);
      final BackupPayload imported;
      try {
        imported = await service.decode(raw: raw, passphrase: passphrase);
      } on BackupException catch (e) {
        if (mounted) _showSnack(_describe(e.error));
        return;
      }
      if (!mounted) return;

      final choice = await showImportPreviewDialog(
        context,
        entryCount: imported.entries.length,
        photoCount: imported.attachments.length,
      );
      if (choice == null || !mounted) return;

      await ref.read(entriesProvider.notifier).importEntries(
            imported.entries,
            merge: choice == ImportMode.merge,
            attachments: imported.attachments,
          );
      _showSnack(
        choice == ImportMode.merge
            ? 'Backup merged into your journal'
            : 'Journal replaced from backup',
      );
    } catch (_) {
      _showSnack('Could not read that file');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool?> _confirmLargeBackup(int sizeBytes) {
    final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Large backup'),
        content: Text(
          'This backup is about $mb MB because of the photos it carries. '
          'Sharing or uploading it may be slow, and some apps limit '
          'attachment sizes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export anyway'),
          ),
        ],
      ),
    );
  }

  static String _describe(BackupError error) => switch (error) {
        BackupError.wrongPassphrase => 'Wrong passphrase for this backup',
        BackupError.unsupportedVersion =>
          'This backup needs a newer version of Reflect',
        BackupError.invalidFormat => 'Not a Reflect backup file',
      };

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Export', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Creates an encrypted backup of your entries and photos that '
            'you can keep anywhere. It can only be opened with the '
            'passphrase you choose here.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Backup passphrase',
            controller: _passphraseController,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Confirm passphrase',
            controller: _confirmController,
            obscureText: true,
            errorText: _exportError,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultButton(
            label: 'Export encrypted backup',
            isLoading: _exporting,
            onPressed: _export,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Restore', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Open a .rfbackup file and either merge it into your current '
            'journal or replace everything with it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultButton(
            label: 'Import backup file',
            variant: VaultButtonVariant.secondary,
            isLoading: _importing,
            onPressed: _import,
          ),
        ],
      ),
    );
  }
}
