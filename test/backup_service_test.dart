import 'dart:convert';
import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/backup/services/backup_service.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

import 'fakes/fakes.dart';

JournalEntry entry(
  String id, {
  String body = 'reflections',
  DateTime? createdAt,
  DateTime? updatedAt,
  List<String> tags = const [],
}) {
  final created = createdAt ?? DateTime(2026, 7, 1, 9);
  return JournalEntry(
    id: id,
    title: 'Title $id',
    body: body,
    mood: 4,
    tags: tags,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  late BackupService service;

  setUp(() {
    service = BackupService(
      keyDerivation: FakeKeyDerivation(),
      cipher: const CipherService(),
      clock: FixedClock(DateTime(2026, 7, 5, 10)),
    );
  });

  test('export produces the documented envelope', () async {
    final raw = await service.export(
      entries: [entry('a'), entry('b')],
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    expect(envelope['formatVersion'], 2);
    expect(envelope['app'], 'reflect');
    expect(envelope['appVersion'], isNotEmpty);
    expect(envelope['createdAt'], '2026-07-05T10:00:00.000');
    expect(envelope['entryCount'], 2);
    expect(envelope['photoCount'], 0);
    expect(envelope['salt'], isNotEmpty);
    expect(envelope['nonce'], isNotEmpty);
    expect(envelope['ciphertext'], isNotEmpty);
  });

  test('ciphertext leaks no plaintext', () async {
    final raw = await service.export(
      entries: [entry('a', body: 'deeply private thought')],
      passphrase: 'correct horse',
    );
    expect(raw.contains('private'), isFalse);
    expect(raw.contains('Title a'), isFalse);
  });

  test('round-trip restores entries exactly, unicode included', () async {
    final original = [
      entry('a', body: 'emoji 🌙 and «quotes»', tags: ['grateful']),
      entry('b', createdAt: DateTime(2025, 12, 31, 23, 59)),
    ];
    final raw = await service.export(
      entries: original,
      passphrase: 'correct horse',
    );
    final restored = await service.decode(
      raw: raw,
      passphrase: 'correct horse',
    );
    expect(restored.entries, original);
    expect(restored.attachments, isEmpty);
  });

  test('photo attachments round-trip through a backup', () async {
    final photoA = Uint8List.fromList(List.generate(600, (i) => i % 251));
    final photoB = Uint8List.fromList([0xFF, 0xD8, 9, 9, 9]);
    final entries = [
      entry('a').copyWith(photoIds: ['ph-a', 'ph-b']),
    ];
    final raw = await service.export(
      entries: entries,
      passphrase: 'correct horse',
      attachments: {'ph-a': photoA, 'ph-b': photoB},
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    expect(envelope['photoCount'], 2);
    // Photo bytes only appear inside the ciphertext.
    expect(raw.contains(base64Encode(photoA)), isFalse);

    final restored = await service.decode(
      raw: raw,
      passphrase: 'correct horse',
    );
    expect(restored.entries.single.photoIds, ['ph-a', 'ph-b']);
    expect(restored.attachments['ph-a'], photoA);
    expect(restored.attachments['ph-b'], photoB);
  });

  test('a v1 backup (entries only, no attachments key) still imports',
      () async {
    // Recreate byte-exactly what BackupService v1 produced: formatVersion 1
    // and a plaintext body without an attachments key.
    final salt = await const CipherService().generateSalt();
    final kdfKey =
        await FakeKeyDerivation().deriveKey(pin: 'legacy pass', salt: salt);
    final plaintext = jsonEncode({
      'entries': [entry('old-1').toJson()..remove('photoIds')],
    });
    final payload = await const CipherService().encrypt(
      plaintext: plaintext,
      keyBytes: kdfKey,
      salt: salt,
    );
    final rawV1 = jsonEncode({
      'formatVersion': 1,
      'app': 'reflect',
      'appVersion': '1.1.0',
      'createdAt': '2026-01-01T00:00:00.000',
      'entryCount': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
    });

    final restored = await service.decode(
      raw: rawV1,
      passphrase: 'legacy pass',
    );
    expect(restored.entries.single.id, 'old-1');
    expect(restored.entries.single.photoIds, isEmpty);
    expect(restored.attachments, isEmpty);
  });

  test('wrong passphrase throws wrongPassphrase', () async {
    final raw = await service.export(
      entries: [entry('a')],
      passphrase: 'correct horse',
    );
    expect(
      () => service.decode(raw: raw, passphrase: 'wrong horse'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('tampered ciphertext also fails as wrongPassphrase', () async {
    final raw = await service.export(
      entries: [entry('a')],
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['ciphertext'] as String);
    bytes[0] ^= 0xFF;
    envelope['ciphertext'] = base64Encode(bytes);
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.wrongPassphrase,
        ),
      ),
    );
  });

  test('garbage input throws invalidFormat', () async {
    for (final junk in ['not json', '{}', '{"salt": 5}', '[]']) {
      expect(
        () => service.decode(raw: junk, passphrase: 'x'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.invalidFormat,
          ),
        ),
        reason: junk,
      );
    }
  });

  test('a future format version is rejected', () async {
    final raw = await service.export(
      entries: [entry('a')],
      passphrase: 'correct horse',
    );
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    envelope['formatVersion'] = 99;
    expect(
      () => service.decode(
        raw: jsonEncode(envelope),
        passphrase: 'correct horse',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.error,
          'error',
          BackupError.unsupportedVersion,
        ),
      ),
    );
  });

  group('merge', () {
    test('adds new ids and keeps untouched entries', () {
      final existing = [entry('a'), entry('b')];
      final imported = [entry('c', createdAt: DateTime(2026, 7, 4))];
      final merged = BackupService.merge(existing, imported);
      expect(merged.map((e) => e.id).toSet(), {'a', 'b', 'c'});
    });

    test('newer updatedAt wins on id clashes — either direction', () {
      final older = entry('a', body: 'old', updatedAt: DateTime(2026, 7, 1));
      final newer = entry('a', body: 'new', updatedAt: DateTime(2026, 7, 3));

      expect(
        BackupService.merge([older], [newer]).single.body,
        'new',
      );
      expect(
        BackupService.merge([newer], [older]).single.body,
        'new',
      );
    });

    test('equal timestamps keep the existing entry', () {
      final mine = entry('a', body: 'mine');
      final theirs = entry('a', body: 'theirs');
      expect(BackupService.merge([mine], [theirs]).single.body, 'mine');
    });

    test('result is sorted newest-created first', () {
      final merged = BackupService.merge(
        [entry('old', createdAt: DateTime(2026, 1, 1))],
        [entry('new', createdAt: DateTime(2026, 6, 1))],
      );
      expect(merged.map((e) => e.id), ['new', 'old']);
    });
  });

  test('suggested file name is date-stamped', () {
    expect(
      BackupService.suggestedFileName(DateTime(2026, 7, 5)),
      'reflect-2026-07-05.rfbackup',
    );
  });
}
