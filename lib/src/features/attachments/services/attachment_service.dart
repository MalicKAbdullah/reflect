import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:reflect/src/core/interfaces/attachment_store.dart';
import 'package:reflect/src/features/attachments/services/photo_codec.dart';
import 'package:reflect/src/features/attachments/services/photo_lru_cache.dart';
import 'package:uuid/uuid.dart';

/// Encrypted photo attachments.
///
/// Every photo is downscaled (in an isolate), encrypted with AES-GCM under
/// the session data key, and written as its own file via [IAttachmentStore].
/// Decryption happens on demand into a small LRU cache that the session
/// notifier clears the moment the app locks — plaintext photo bytes exist
/// only in memory, only while unlocked.
final class AttachmentService {
  AttachmentService({
    required IAttachmentStore store,
    required CipherService cipher,
    PhotoLruCache? cache,
  })  : _store = store,
        _cipher = cipher,
        cache = cache ?? PhotoLruCache();

  final IAttachmentStore _store;
  final CipherService _cipher;
  final PhotoLruCache cache;

  static const Uuid _uuid = Uuid();

  /// Downscales, encrypts and stores a freshly picked photo. Returns the new
  /// attachment id, or null when [original] is not a decodable image.
  Future<String?> importPhoto({
    required Uint8List original,
    required Uint8List key,
    required Uint8List salt,
  }) async {
    final jpeg = await PhotoCodec.prepare(original);
    if (jpeg == null) return null;
    final id = _uuid.v4();
    await _writeEncrypted(id, jpeg, key, salt);
    cache.put(id, jpeg);
    return id;
  }

  /// Decrypts the photo for [id] (cache-first). Returns null when the file
  /// is missing or the key cannot authenticate it.
  Future<Uint8List?> loadPhoto({
    required String id,
    required Uint8List key,
  }) async {
    final hit = cache.get(id);
    if (hit != null) return hit;

    final raw = await _store.read(id);
    if (raw == null) return null;
    try {
      final b64 = await _cipher.decrypt(
        payload: EncryptedPayload.fromBytes(raw),
        keyBytes: key,
      );
      final bytes = Uint8List.fromList(base64Decode(b64));
      cache.put(id, bytes);
      return bytes;
    } catch (_) {
      // Wrong key or corrupted file — treat as unavailable.
      return null;
    }
  }

  Future<void> deletePhoto(String id) async {
    cache.evict(id);
    await _store.delete(id);
  }

  Future<void> deletePhotos(Iterable<String> ids) async {
    for (final id in ids) {
      await deletePhoto(id);
    }
  }

  /// Plaintext bytes for [ids], for inclusion in an encrypted backup.
  /// Missing or undecryptable photos are skipped.
  Future<Map<String, Uint8List>> exportPlaintext({
    required Iterable<String> ids,
    required Uint8List key,
  }) async {
    final result = <String, Uint8List>{};
    for (final id in ids) {
      final bytes = await loadPhoto(id: id, key: key);
      if (bytes != null) result[id] = bytes;
    }
    return result;
  }

  /// Encrypts and stores photos restored from a backup, keeping their ids
  /// (entries reference them). Invalid ids are skipped, never written.
  Future<void> importPlaintext({
    required Map<String, Uint8List> photos,
    required Uint8List key,
    required Uint8List salt,
  }) async {
    for (final entry in photos.entries) {
      try {
        await _writeEncrypted(entry.key, entry.value, key, salt);
      } on ArgumentError {
        // Unsafe id inside a crafted backup — skip it.
      }
    }
  }

  /// Deletes stored attachments that no entry references any more.
  Future<void> sweepOrphans(Set<String> referencedIds) async {
    for (final id in await _store.list()) {
      if (!referencedIds.contains(id)) {
        await deletePhoto(id);
      }
    }
  }

  /// Zeroes and empties the plaintext cache. Called whenever the session
  /// locks so photos are unreadable while locked.
  void clearCache() => cache.clear();

  /// Deletes every attachment file and the cache (part of erase-all).
  Future<void> eraseAll() async {
    clearCache();
    await _store.deleteAll();
  }

  Future<void> _writeEncrypted(
    String id,
    Uint8List jpeg,
    Uint8List key,
    Uint8List salt,
  ) async {
    final payload = await _cipher.encrypt(
      plaintext: base64Encode(jpeg),
      keyBytes: key,
      salt: salt,
    );
    await _store.write(id, payload.toBytes());
  }
}
