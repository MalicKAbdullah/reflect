import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_backup/core_backup.dart';
import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reflect/src/core/clock.dart';
import 'package:reflect/src/core/interfaces/attachment_store.dart';
import 'package:reflect/src/core/interfaces/biometric_auth.dart';
import 'package:reflect/src/core/interfaces/journal_file_store.dart';
import 'package:reflect/src/core/interfaces/key_derivation.dart';
import 'package:reflect/src/core/interfaces/reminder_scheduler.dart';
import 'package:reflect/src/features/attachments/services/attachment_service.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/biometric_unlock_service.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';
import 'package:reflect/src/features/backup/services/backup_service.dart';
import 'package:reflect/src/features/entries/data/journal_repository.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';

/// Composition root. Tests override the leaf providers (storage, file store,
/// key derivation, clock) with in-memory fakes — no platform channels.
final clockProvider = Provider<Clock>((_) => const SystemClock());

final secureStorageProvider = Provider<ISecureStorage>(
  (_) => const SecureStorageImpl(FlutterSecureStorage()),
);

final fileStoreProvider = Provider<IJournalFileStore>(
  (_) => const DocumentsJournalFileStore(),
);

final cipherServiceProvider = Provider<CipherService>(
  (_) => const CipherService(),
);

final keyDerivationProvider = Provider<IKeyDerivation>(
  (_) => const Argon2KeyDerivation(KeyDerivationService()),
);

final pinAuthServiceProvider = Provider<PinAuthService>(
  (ref) => PinAuthService(
    storage: ref.watch(secureStorageProvider),
    keyDerivation: ref.watch(keyDerivationProvider),
    cipher: ref.watch(cipherServiceProvider),
    fileStore: ref.watch(fileStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(
    fileStore: ref.watch(fileStoreProvider),
    cipher: ref.watch(cipherServiceProvider),
  ),
);

final biometricAuthProvider = Provider<IBiometricAuth>(
  (_) => LocalAuthBiometric(),
);

final biometricUnlockServiceProvider = Provider<BiometricUnlockService>(
  (ref) => BiometricUnlockService(
    storage: ref.watch(secureStorageProvider),
    biometric: ref.watch(biometricAuthProvider),
    pinAuth: ref.watch(pinAuthServiceProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    keyDerivation: ref.watch(keyDerivationProvider),
    cipher: ref.watch(cipherServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Backup destination folder (shared engine). Android uses the Storage Access
/// Framework so a Google Drive folder can be picked; iOS uses app documents.
final backupFolderProvider = Provider<IBackupFolder>(
  (ref) =>
      Platform.isAndroid ? SafBackupFolder() : const AppDocumentsBackupFolder(),
);

/// Scheduled auto-backup engine (shared core_backup), namespaced to Reflect.
final autoBackupServiceProvider = Provider<AutoBackupService>(
  (ref) => AutoBackupService(
    storage: ref.watch(secureStorageProvider),
    folder: ref.watch(backupFolderProvider),
    keyPrefix: 'reflect',
    fileLabel: 'Reflect',
    fileExtension: BackupService.fileExtension,
    now: () => ref.read(clockProvider).now(),
  ),
);

/// Produces the encrypted `.rfbackup` bytes for the current journal (entries +
/// photo attachments), reusing the existing [BackupService]. Requires an
/// unlocked session for the data key.
final reflectBackupProducerProvider = Provider<BackupProducer>((ref) {
  return (passphrase) async {
    final entries = await ref.read(entriesProvider.future);
    final attachments =
        await ref.read(attachmentServiceProvider).exportPlaintext(
      ids: {for (final e in entries) ...e.photoIds},
      key: ref.read(sessionProvider.notifier).dataKey,
    );
    final json = await ref.read(backupServiceProvider).export(
          entries: entries,
          passphrase: passphrase!,
          attachments: attachments,
        );
    return Uint8List.fromList(utf8.encode(json));
  };
});

final attachmentStoreProvider = Provider<IAttachmentStore>(
  (_) => const DocumentsAttachmentStore(),
);

/// Encrypted photo attachments. The session notifier clears its plaintext
/// cache on every lock.
final attachmentServiceProvider = Provider<AttachmentService>(
  (ref) => AttachmentService(
    store: ref.watch(attachmentStoreProvider),
    cipher: ref.watch(cipherServiceProvider),
  ),
);

/// Daily reminder scheduling. A no-op by default (tests, unsupported
/// platforms); main() overrides it with the notification-plugin
/// implementation.
final reminderSchedulerProvider = Provider<IReminderScheduler>(
  (_) => const NoopReminderScheduler(),
);

// -- In-app update (core_update) ------------------------------------------

/// Secure-storage key for the auto-check preference.
const String updateAutoCheckKey = 'reflect_update_autocheck';

final updateServiceProvider = Provider<IUpdateService>(
  (_) => GithubUpdateService(owner: 'MalicKAbdullah', repo: 'reflect'),
);

/// Auto-check preference (persisted; on by default). Toggle in Settings.
final updateAutoCheckProvider = FutureProvider<bool>(
  (ref) async =>
      await ref.watch(secureStorageProvider).read(key: updateAutoCheckKey) !=
      'false',
);

/// The pending update (null when disabled, up to date, or offline).
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (!await ref.watch(updateAutoCheckProvider.future)) return null;
  return ref.watch(updateServiceProvider).check();
});

/// Session-only dismissal of the update banner.
final updateDismissedProvider = StateProvider<bool>((_) => false);
