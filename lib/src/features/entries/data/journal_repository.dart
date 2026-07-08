import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:reflect/src/core/interfaces/journal_file_store.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// Persists the journal as one AES-GCM-encrypted JSON document.
///
/// The whole entry list is serialized, encrypted with the session data key,
/// and written to a single file. Decrypted data exists only in memory.
final class JournalRepository {
  const JournalRepository({
    required IJournalFileStore fileStore,
    required CipherService cipher,
  })  : _fileStore = fileStore,
        _cipher = cipher;

  final IJournalFileStore _fileStore;
  final CipherService _cipher;

  static const int _formatVersion = 1;

  Future<List<JournalEntry>> load(Uint8List key) async {
    final bytes = await _fileStore.read();
    if (bytes == null) return const [];

    final plaintext = await _cipher.decrypt(
      payload: EncryptedPayload.fromBytes(bytes),
      keyBytes: key,
    );
    final doc = jsonDecode(plaintext) as Map<String, dynamic>;
    final list = doc['entries'] as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(JournalEntry.fromJson)
        .toList();
  }

  Future<void> save(
    List<JournalEntry> entries,
    Uint8List key,
    Uint8List salt,
  ) async {
    final plaintext = jsonEncode({
      'version': _formatVersion,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
    final payload = await _cipher.encrypt(
      plaintext: plaintext,
      keyBytes: key,
      salt: salt,
    );
    await _fileStore.write(payload.toBytes());
  }
}
