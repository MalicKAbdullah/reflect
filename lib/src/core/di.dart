import 'package:core_crypto/core_crypto.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reflect/src/core/clock.dart';
import 'package:reflect/src/core/interfaces/attachment_store.dart';
import 'package:reflect/src/core/interfaces/biometric_auth.dart';
import 'package:reflect/src/core/interfaces/journal_file_store.dart';
import 'package:reflect/src/core/interfaces/key_derivation.dart';
import 'package:reflect/src/core/interfaces/reminder_scheduler.dart';
import 'package:reflect/src/features/attachments/services/attachment_service.dart';
import 'package:reflect/src/features/auth/services/biometric_unlock_service.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';
import 'package:reflect/src/features/backup/services/backup_service.dart';
import 'package:reflect/src/features/entries/data/journal_repository.dart';

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
