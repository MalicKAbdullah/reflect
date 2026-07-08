import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/data/journal_repository.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

import 'fakes/fakes.dart';

void main() {
  late InMemoryFileStore fileStore;
  late JournalRepository repo;
  final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
  final salt = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  setUp(() {
    fileStore = InMemoryFileStore();
    repo = JournalRepository(
      fileStore: fileStore,
      cipher: const CipherService(),
    );
  });

  JournalEntry entry(String id) => JournalEntry(
        id: id,
        title: 'Title $id',
        body: 'A quiet day — reflections on $id 🌿',
        mood: 4,
        tags: const ['calm', 'grateful'],
        createdAt: DateTime(2026, 7, 1, 8, 30),
        updatedAt: DateTime(2026, 7, 1, 9, 45),
      );

  test('load returns empty list when no journal exists', () async {
    expect(await repo.load(key), isEmpty);
  });

  test('encrypt/decrypt round-trip preserves entries exactly', () async {
    final entries = [entry('one'), entry('two'), entry('three')];
    await repo.save(entries, key, salt);
    expect(await repo.load(key), entries);
  });

  test('stored bytes are not plaintext', () async {
    await repo.save([entry('secret')], key, salt);
    final raw = String.fromCharCodes(fileStore.bytes!);
    expect(raw.contains('secret'), isFalse);
    expect(raw.contains('Title'), isFalse);
  });

  test('decrypting with the wrong key fails (GCM auth)', () async {
    await repo.save([entry('one')], key, salt);
    final wrongKey = Uint8List.fromList(List.generate(32, (i) => i));
    expect(() => repo.load(wrongKey), throwsA(anything));
  });

  test('tampered ciphertext fails to decrypt', () async {
    await repo.save([entry('one')], key, salt);
    final tampered = Uint8List.fromList(fileStore.bytes!);
    tampered[tampered.length - 1] ^= 0xFF;
    fileStore.bytes = tampered;
    expect(() => repo.load(key), throwsA(anything));
  });

  test('a v1 journal document (no photoIds — live data) loads gracefully',
      () async {
    // Byte-for-byte what Reflect 1.1 wrote: version 1, entries without a
    // photoIds key. The owner has live data in this shape.
    const v1Document = '{"version":1,"entries":['
        '{"id":"live-a","title":"First entry","body":"plain **markdown**",'
        '"mood":4,"tags":["calm"],'
        '"createdAt":"2025-11-02T21:15:00.000",'
        '"updatedAt":"2025-11-02T21:20:00.000"},'
        '{"id":"live-b","title":"","body":"untitled one","mood":2,'
        '"tags":[],'
        '"createdAt":"2025-11-03T08:00:00.000",'
        '"updatedAt":"2025-11-03T08:00:00.000"}]}';
    final payload = await const CipherService().encrypt(
      plaintext: v1Document,
      keyBytes: key,
      salt: salt,
    );
    fileStore.bytes = payload.toBytes();

    final loaded = await repo.load(key);
    expect(loaded, hasLength(2));
    expect(loaded.first.id, 'live-a');
    expect(loaded.first.photoIds, isEmpty);
    expect(loaded.last.body, 'untitled one');

    // And saving it back (now v2 with photoIds) still round-trips.
    await repo.save(loaded, key, salt);
    final reloaded = await repo.load(key);
    expect(reloaded, loaded);
    final doc = jsonDecode(await const CipherService().decrypt(
      payload: EncryptedPayload.fromBytes(fileStore.bytes!),
      keyBytes: key,
    )) as Map<String, dynamic>;
    expect((doc['entries'] as List).first, containsPair('photoIds', []));
  });

  test('saving an empty list round-trips', () async {
    await repo.save([entry('one')], key, salt);
    await repo.save([], key, salt);
    expect(await repo.load(key), isEmpty);
  });
}
