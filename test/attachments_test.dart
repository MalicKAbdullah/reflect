import 'dart:typed_data';

import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/attachments/services/attachment_service.dart';
import 'package:reflect/src/features/attachments/services/photo_codec.dart';
import 'package:reflect/src/features/attachments/services/photo_lru_cache.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';

import 'fakes/fakes.dart';

/// A decodable in-memory photo of the given size.
Uint8List testJpeg({int width = 48, int height = 32}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 120, 60));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
  final salt = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  group('PhotoCodec', () {
    test('downscales oversized photos to at most 1600 px, JPEG output', () {
      final big = testJpeg(width: 2400, height: 1200);
      final out = PhotoCodec.prepareSync(big)!;
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, PhotoCodec.maxDimension);
      expect(decoded.height, 800); // Aspect ratio preserved.
      expect(out.sublist(0, 2), [0xFF, 0xD8]); // JPEG magic.
    });

    test('portrait photos downscale on the long (height) side', () {
      final tall = testJpeg(width: 300, height: 3200);
      final decoded = img.decodeImage(PhotoCodec.prepareSync(tall)!)!;
      expect(decoded.height, PhotoCodec.maxDimension);
      expect(decoded.width, 150);
    });

    test('small photos are re-encoded but never upscaled', () {
      final small = testJpeg(width: 100, height: 80);
      final decoded = img.decodeImage(PhotoCodec.prepareSync(small)!)!;
      expect(decoded.width, 100);
      expect(decoded.height, 80);
    });

    test('garbage bytes return null instead of throwing', () {
      expect(
        PhotoCodec.prepareSync(Uint8List.fromList([1, 2, 3, 4])),
        isNull,
      );
    });
  });

  group('PhotoLruCache', () {
    test('evicts least-recently-used when over budget and zeroes it', () {
      final cache = PhotoLruCache(maxBytes: 10);
      final a = Uint8List.fromList([1, 1, 1, 1]);
      final b = Uint8List.fromList([2, 2, 2, 2]);
      cache.put('a', a);
      cache.put('b', b);
      cache.get('a'); // 'a' becomes most recently used.
      cache.put('c', Uint8List.fromList([3, 3, 3, 3])); // Evicts 'b'.

      expect(cache.get('b'), isNull);
      expect(b, everyElement(0)); // Evicted plaintext was wiped.
      expect(cache.get('a'), isNotNull);
    });

    test('clear zeroes every buffer and empties the cache', () {
      final cache = PhotoLruCache();
      final bytes = Uint8List.fromList([9, 8, 7]);
      cache.put('x', bytes);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.totalBytes, 0);
      expect(bytes, everyElement(0));
    });
  });

  group('AttachmentService', () {
    late FakeAttachmentStore store;
    late AttachmentService service;

    setUp(() {
      store = FakeAttachmentStore();
      service = AttachmentService(store: store, cipher: const CipherService());
    });

    test('import/load round-trip; at-rest bytes are not the JPEG', () async {
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: key,
        salt: salt,
      ))!;

      final atRest = store.files[id]!;
      expect(atRest.sublist(0, 2), isNot([0xFF, 0xD8])); // Encrypted.

      service.clearCache();
      final loaded = await service.loadPhoto(id: id, key: key);
      expect(loaded, isNotNull);
      expect(img.decodeImage(loaded!), isNotNull);
    });

    test('second load is served from cache (no extra store read)', () async {
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: key,
        salt: salt,
      ))!;
      service.clearCache();

      await service.loadPhoto(id: id, key: key);
      final readsAfterFirst = store.readCount;
      await service.loadPhoto(id: id, key: key);
      expect(store.readCount, readsAfterFirst);
    });

    test('wrong key yields null, never plaintext', () async {
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: key,
        salt: salt,
      ))!;
      service.clearCache();
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => i));
      expect(await service.loadPhoto(id: id, key: wrongKey), isNull);
    });

    test('deletePhotos removes files and cache entries', () async {
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: key,
        salt: salt,
      ))!;
      await service.deletePhotos([id]);
      expect(store.files, isEmpty);
      expect(await service.loadPhoto(id: id, key: key), isNull);
    });

    test('sweepOrphans keeps referenced ids only', () async {
      final keep = (await service.importPhoto(
          original: testJpeg(), key: key, salt: salt))!;
      final drop = (await service.importPhoto(
          original: testJpeg(), key: key, salt: salt))!;
      await service.sweepOrphans({keep});
      expect(store.files.keys, [keep]);
      expect(store.files.containsKey(drop), isFalse);
    });
  });

  group('session integration', () {
    late FakeAttachmentStore store;
    late ProviderContainer container;

    setUp(() {
      store = FakeAttachmentStore();
      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          fileStoreProvider.overrideWithValue(InMemoryFileStore()),
          attachmentStoreProvider.overrideWithValue(store),
          keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 7, 3))),
        ],
      );
      container.listen(sessionProvider, (_, __) {});
      container.listen(entriesProvider, (_, __) {});
    });

    tearDown(() => container.dispose());

    test('locking clears (and zeroes) the plaintext photo cache', () async {
      final session = container.read(sessionProvider.notifier);
      await session.setup('123456');

      final service = container.read(attachmentServiceProvider);
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: session.dataKey,
        salt: session.salt,
      ))!;
      final cached = (await service.loadPhoto(
        id: id,
        key: session.dataKey,
      ))!;
      expect(service.cache.length, 1);

      session.lock();
      expect(service.cache.length, 0);
      expect(cached, everyElement(0)); // Plaintext gone from memory.
      expect(store.files.containsKey(id), isTrue); // Encrypted file stays.
    });

    test('deleting an entry deletes its attachment files', () async {
      final session = container.read(sessionProvider.notifier);
      await session.setup('123456');
      final service = container.read(attachmentServiceProvider);
      final id = (await service.importPhoto(
        original: testJpeg(),
        key: session.dataKey,
        salt: session.salt,
      ))!;

      final entries = container.read(entriesProvider.notifier);
      final entry = await entries.addEntry(
        body: 'photo day',
        mood: 4,
        photoIds: [id],
      );
      expect(store.files.containsKey(id), isTrue);

      await entries.deleteEntry(entry.id);
      expect(store.files, isEmpty);
    });

    test('erase-all deletes every attachment file', () async {
      final session = container.read(sessionProvider.notifier);
      await session.setup('123456');
      final service = container.read(attachmentServiceProvider);
      await service.importPhoto(
        original: testJpeg(),
        key: session.dataKey,
        salt: session.salt,
      );
      expect(store.files, isNotEmpty);

      await session.eraseAll();
      expect(store.files, isEmpty);
    });
  });
}
