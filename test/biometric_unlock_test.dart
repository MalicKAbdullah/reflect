import 'package:core_crypto/core_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/services/biometric_unlock_service.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

import 'fakes/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late FakeBiometricAuth biometric;
  late PinAuthService pinAuth;
  late BiometricUnlockService service;

  setUp(() async {
    storage = FakeSecureStorage();
    fileStore = InMemoryFileStore();
    biometric = FakeBiometricAuth();
    pinAuth = PinAuthService(
      storage: storage,
      keyDerivation: FakeKeyDerivation(),
      cipher: const CipherService(),
      fileStore: fileStore,
      clock: FixedClock(DateTime(2026, 7, 5, 10)),
    );
    service = BiometricUnlockService(
      storage: storage,
      biometric: biometric,
      pinAuth: pinAuth,
    );
  });

  test('disabled by default', () async {
    expect(await service.isEnabled(), isFalse);
    expect(await service.unlock(), isNull);
    expect(biometric.promptCount, 0);
  });

  test('enable prompts, stores the wrapped key, and flips the flag', () async {
    final setup = await pinAuth.setupPin('123456');
    expect(await service.enable(setup.key), isTrue);
    expect(biometric.promptCount, 1);
    expect(await service.isEnabled(), isTrue);
    expect(storage.store[ReflectKeys.biometricKey], isNotNull);
  });

  test('enable fails when hardware is unavailable or the prompt is declined',
      () async {
    final setup = await pinAuth.setupPin('123456');

    biometric.available = false;
    expect(await service.enable(setup.key), isFalse);
    expect(await service.isEnabled(), isFalse);

    biometric.available = true;
    biometric.authenticates = false;
    expect(await service.enable(setup.key), isFalse);
    expect(await service.isEnabled(), isFalse);
    expect(storage.store[ReflectKeys.biometricKey], isNull);
  });

  test('disable wipes the stored key', () async {
    final setup = await pinAuth.setupPin('123456');
    await service.enable(setup.key);
    await service.disable();
    expect(await service.isEnabled(), isFalse);
    expect(storage.store[ReflectKeys.biometricKey], isNull);
    expect(await service.unlock(), isNull);
  });

  test('unlock returns a verified key and resets PIN attempts', () async {
    final setup = await pinAuth.setupPin('123456');
    await service.enable(setup.key);

    // Rack up failed PIN attempts first.
    await pinAuth.unlock('999999');
    expect(storage.store[ReflectKeys.failedAttempts], '1');

    final result = await service.unlock();
    expect(result, isNotNull);
    expect(result!.key, setup.key);
    expect(result.salt, setup.salt);
    expect(storage.store[ReflectKeys.failedAttempts], isNull);
  });

  test('unlock fails when the prompt is declined', () async {
    final setup = await pinAuth.setupPin('123456');
    await service.enable(setup.key);

    biometric.authenticates = false;
    expect(await service.unlock(), isNull);
    expect(await service.isEnabled(), isTrue); // still on; PIN still works
  });

  test('a stale wrapped key is rejected and biometrics disabled', () async {
    final setup = await pinAuth.setupPin('123456');
    await service.enable(setup.key);

    // PIN change without refreshKey → stored key no longer decrypts the
    // verifier.
    await pinAuth.changePin(oldPin: '123456', newPin: '654321');

    expect(await service.unlock(), isNull);
    expect(await service.isEnabled(), isFalse);
  });

  test('refreshKey keeps biometric unlock working after a PIN change',
      () async {
    final setup = await pinAuth.setupPin('123456');
    await service.enable(setup.key);

    final changed = await pinAuth.changePin(
      oldPin: '123456',
      newPin: '654321',
    ) as UnlockSuccess;
    await service.refreshKey(changed.key);

    final result = await service.unlock();
    expect(result, isNotNull);
    expect(result!.key, changed.key);
  });

  test('refreshKey is a no-op while biometrics are off', () async {
    final setup = await pinAuth.setupPin('123456');
    await service.refreshKey(setup.key);
    expect(storage.store[ReflectKeys.biometricKey], isNull);
  });
}
