import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';
import 'package:reflect/src/features/entries/data/journal_repository.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

import 'fakes/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late FixedClock clock;
  late PinAuthService auth;

  setUp(() {
    storage = FakeSecureStorage();
    fileStore = InMemoryFileStore();
    clock = FixedClock(DateTime(2026, 7, 3, 12));
    auth = PinAuthService(
      storage: storage,
      keyDerivation: FakeKeyDerivation(),
      cipher: const CipherService(),
      fileStore: fileStore,
      clock: clock,
    );
  });

  group('setup and unlock', () {
    test('hasPin is false before setup, true after', () async {
      expect(await auth.hasPin(), isFalse);
      await auth.setupPin('123456');
      expect(await auth.hasPin(), isTrue);
    });

    test('setup stores salt and verifier but never the PIN', () async {
      await auth.setupPin('123456');
      expect(storage.store[ReflectKeys.salt], isNotNull);
      expect(storage.store[ReflectKeys.verifier], isNotNull);
      expect(storage.store.values.any((v) => v.contains('123456')), isFalse);
    });

    test('correct PIN unlocks and returns the same key as setup', () async {
      final setup = await auth.setupPin('123456');
      final result = await auth.unlock('123456');
      expect(result, isA<UnlockSuccess>());
      expect((result as UnlockSuccess).key, setup.key);
    });

    test('wrong PIN fails with attempt count', () async {
      await auth.setupPin('123456');
      final result = await auth.unlock('654321');
      expect(result, isA<UnlockWrongPin>());
      expect((result as UnlockWrongPin).failedAttempts, 1);
      expect(result.cooldown, isNull);
    });

    test('successful unlock resets the attempt counter', () async {
      await auth.setupPin('123456');
      await auth.unlock('000000');
      await auth.unlock('000001');
      await auth.unlock('123456');
      final result = await auth.unlock('000000');
      expect((result as UnlockWrongPin).failedAttempts, 1);
    });
  });

  group('cooldown', () {
    test('5th failure triggers a 30s cooldown', () async {
      await auth.setupPin('123456');
      UnlockResult? result;
      for (var i = 0; i < 5; i++) {
        result = await auth.unlock('999999');
      }
      final wrong = result! as UnlockWrongPin;
      expect(wrong.failedAttempts, 5);
      expect(wrong.cooldown, const Duration(seconds: 30));
    });

    test('attempts during cooldown are rejected without KDF work', () async {
      await auth.setupPin('123456');
      for (var i = 0; i < 5; i++) {
        await auth.unlock('999999');
      }
      // Even the correct PIN is rejected while cooling down.
      final result = await auth.unlock('123456');
      expect(result, isA<UnlockCoolingDown>());
      expect(
        (result as UnlockCoolingDown).remaining,
        const Duration(seconds: 30),
      );
    });

    test('cooldown expires with time and escalates on next failure', () async {
      await auth.setupPin('123456');
      for (var i = 0; i < 5; i++) {
        await auth.unlock('999999');
      }
      clock.advance(const Duration(seconds: 31));
      final sixth = await auth.unlock('999999');
      expect((sixth as UnlockWrongPin).failedAttempts, 6);
      expect(sixth.cooldown, const Duration(seconds: 60));
    });

    test('correct PIN works after cooldown expires', () async {
      await auth.setupPin('123456');
      for (var i = 0; i < 5; i++) {
        await auth.unlock('999999');
      }
      clock.advance(const Duration(minutes: 1));
      expect(await auth.unlock('123456'), isA<UnlockSuccess>());
    });

    test('escalation schedule doubles and caps at 15 minutes', () {
      expect(PinAuthService.cooldownFor(4), Duration.zero);
      expect(PinAuthService.cooldownFor(5), const Duration(seconds: 30));
      expect(PinAuthService.cooldownFor(6), const Duration(seconds: 60));
      expect(PinAuthService.cooldownFor(7), const Duration(seconds: 120));
      expect(PinAuthService.cooldownFor(9), const Duration(seconds: 480));
      expect(PinAuthService.cooldownFor(10), const Duration(minutes: 15));
      expect(PinAuthService.cooldownFor(50), const Duration(minutes: 15));
    });

    test('failed attempts persist across service restarts', () async {
      await auth.setupPin('123456');
      for (var i = 0; i < 5; i++) {
        await auth.unlock('999999');
      }
      // New service instance over the same storage (simulated app restart).
      final restarted = PinAuthService(
        storage: storage,
        keyDerivation: FakeKeyDerivation(),
        cipher: const CipherService(),
        fileStore: fileStore,
        clock: clock,
      );
      expect(await restarted.unlock('123456'), isA<UnlockCoolingDown>());
    });
  });

  group('change PIN', () {
    JournalRepository repo() =>
        JournalRepository(fileStore: fileStore, cipher: const CipherService());

    JournalEntry sample(String id) => JournalEntry(
          id: id,
          title: 'Title $id',
          body: 'Body of $id',
          mood: 4,
          tags: const ['calm'],
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 2),
        );

    test('re-encryption round-trip: data readable with new PIN only', () async {
      final setup = await auth.setupPin('123456');
      final entries = [sample('a'), sample('b')];
      await repo().save(entries, setup.key, setup.salt);

      final changed = await auth.changePin(oldPin: '123456', newPin: '777777');
      expect(changed, isA<UnlockSuccess>());
      final newKey = (changed as UnlockSuccess).key;

      // Data decrypts with the new key.
      expect(await repo().load(newKey), entries);

      // New PIN unlocks; the old one no longer does.
      expect(await auth.unlock('777777'), isA<UnlockSuccess>());
      expect(await auth.unlock('123456'), isA<UnlockWrongPin>());

      // The old key can no longer decrypt the journal file.
      expect(() => repo().load(setup.key), throwsA(anything));
    });

    test('change PIN rotates the salt', () async {
      await auth.setupPin('123456');
      final saltBefore = storage.store[ReflectKeys.salt];
      await auth.changePin(oldPin: '123456', newPin: '777777');
      expect(storage.store[ReflectKeys.salt], isNot(saltBefore));
    });

    test('wrong old PIN leaves everything unchanged', () async {
      final setup = await auth.setupPin('123456');
      await repo().save([sample('a')], setup.key, setup.salt);
      final bytesBefore = fileStore.bytes;

      final result = await auth.changePin(oldPin: '000000', newPin: '777777');
      expect(result, isA<UnlockWrongPin>());
      expect(fileStore.bytes, bytesBefore);
      expect(await auth.unlock('123456'), isA<UnlockSuccess>());
    });

    test('change PIN works with an empty journal', () async {
      await auth.setupPin('123456');
      final result = await auth.changePin(oldPin: '123456', newPin: '777777');
      expect(result, isA<UnlockSuccess>());
      expect(await auth.unlock('777777'), isA<UnlockSuccess>());
    });
  });

  group('erase', () {
    test('eraseAll wipes journal file and secure storage', () async {
      final setup = await auth.setupPin('123456');
      await JournalRepository(
        fileStore: fileStore,
        cipher: const CipherService(),
      ).save(
        [
          JournalEntry(
            id: 'a',
            body: 'b',
            mood: 3,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
        setup.key,
        setup.salt,
      );

      await auth.eraseAll();
      expect(fileStore.bytes, isNull);
      expect(storage.store, isEmpty);
      expect(await auth.hasPin(), isFalse);
    });
  });
}
