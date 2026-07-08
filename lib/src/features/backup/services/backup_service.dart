import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:reflect/src/core/app_info.dart';
import 'package:reflect/src/core/clock.dart';
import 'package:reflect/src/core/interfaces/key_derivation.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// Why a backup could not be read.
enum BackupError { invalidFormat, unsupportedVersion, wrongPassphrase }

final class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException($error)';
}

/// A decoded backup: entries plus the plaintext bytes of their photo
/// attachments (empty for v1 backups, which predate photos).
final class BackupPayload {
  const BackupPayload({required this.entries, this.attachments = const {}});

  final List<JournalEntry> entries;

  /// Photo id -> plaintext JPEG bytes, ready to re-encrypt under the
  /// session key on import.
  final Map<String, Uint8List> attachments;
}

/// Encrypted `.rfbackup` export/import.
///
/// The file is a JSON envelope `{formatVersion, app, appVersion, createdAt,
/// entryCount, photoCount, salt, nonce, ciphertext}` where the ciphertext is
/// the entries-and-attachments JSON encrypted with AES-GCM under an Argon2id
/// key derived from a separate backup passphrase (independent of the PIN).
/// Photos travel inside the encrypted body, so the passphrase alone restores
/// everything. Version 1 files (entries only) still import.
final class BackupService {
  const BackupService({
    required IKeyDerivation keyDerivation,
    required CipherService cipher,
    required Clock clock,
  })  : _kdf = keyDerivation,
        _cipher = cipher,
        _clock = clock;

  final IKeyDerivation _kdf;
  final CipherService _cipher;
  final Clock _clock;

  static const int formatVersion = 2;
  static const String fileExtension = 'rfbackup';
  static const int minPassphraseLength = 8;

  /// Files past this size get a heads-up in the export UI (sharing very
  /// large files is flaky on some platforms).
  static const int largeBackupBytes = 25 * 1024 * 1024;

  /// Serializes and encrypts [entries] (and their photo [attachments],
  /// plaintext bytes keyed by photo id) under [passphrase].
  Future<String> export({
    required List<JournalEntry> entries,
    required String passphrase,
    Map<String, Uint8List> attachments = const {},
  }) async {
    final salt = await _cipher.generateSalt();
    final key = await _kdf.deriveKey(pin: passphrase, salt: salt);
    final plaintext = jsonEncode({
      'entries': entries.map((e) => e.toJson()).toList(),
      'attachments': {
        for (final photo in attachments.entries)
          photo.key: base64Encode(photo.value),
      },
    });
    final payload = await _cipher.encrypt(
      plaintext: plaintext,
      keyBytes: key,
      salt: salt,
    );
    key.fillRange(0, key.length, 0);
    return jsonEncode({
      'formatVersion': formatVersion,
      'app': 'reflect',
      'appVersion': AppInfo.version,
      'createdAt': _clock.now().toIso8601String(),
      'entryCount': entries.length,
      'photoCount': attachments.length,
      'salt': base64Encode(salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
    });
  }

  /// Decrypts a backup produced by [export] (any supported version).
  /// Throws [BackupException] on a malformed file, unsupported version, or
  /// wrong passphrase.
  Future<BackupPayload> decode({
    required String raw,
    required String passphrase,
  }) async {
    final Map<String, dynamic> envelope;
    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List ciphertext;
    try {
      envelope = jsonDecode(raw) as Map<String, dynamic>;
      salt = base64Decode(envelope['salt'] as String);
      nonce = base64Decode(envelope['nonce'] as String);
      ciphertext = base64Decode(envelope['ciphertext'] as String);
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
    final version = envelope['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const BackupException(BackupError.unsupportedVersion);
    }

    final key = await _kdf.deriveKey(pin: passphrase, salt: salt);
    final String plaintext;
    try {
      plaintext = await _cipher.decrypt(
        payload: EncryptedPayload(
          ciphertext: ciphertext,
          nonce: nonce,
          salt: salt,
        ),
        keyBytes: key,
      );
    } catch (_) {
      // AES-GCM authentication failed: wrong passphrase (or tampered file).
      throw const BackupException(BackupError.wrongPassphrase);
    } finally {
      key.fillRange(0, key.length, 0);
    }

    try {
      final doc = jsonDecode(plaintext) as Map<String, dynamic>;
      final entries = (doc['entries'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(JournalEntry.fromJson)
          .toList();
      // Absent in v1 backups (no photos back then).
      final rawAttachments =
          (doc['attachments'] as Map<String, dynamic>?) ?? const {};
      return BackupPayload(
        entries: entries,
        attachments: {
          for (final photo in rawAttachments.entries)
            photo.key: base64Decode(photo.value as String),
        },
      );
    } catch (_) {
      throw const BackupException(BackupError.invalidFormat);
    }
  }

  /// Merges [imported] into [existing] by id: entries with a new id are
  /// added, clashes keep whichever side has the newer `updatedAt`.
  /// Returns a fresh list sorted newest-created first.
  static List<JournalEntry> merge(
    List<JournalEntry> existing,
    List<JournalEntry> imported,
  ) {
    final byId = {for (final e in existing) e.id: e};
    for (final candidate in imported) {
      final current = byId[candidate.id];
      if (current == null || candidate.updatedAt.isAfter(current.updatedAt)) {
        byId[candidate.id] = candidate;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static String suggestedFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'reflect-${now.year}-${two(now.month)}-${two(now.day)}'
        '.$fileExtension';
  }
}
