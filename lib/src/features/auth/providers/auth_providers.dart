import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

enum AuthStatus { unknown, needsOnboarding, needsSetup, locked, unlocked }

final sessionProvider = NotifierProvider<SessionNotifier, AuthStatus>(
  SessionNotifier.new,
);

/// Holds the session status. The decrypted data key lives only inside this
/// notifier (never in widget state) and is zeroed on lock.
final class SessionNotifier extends Notifier<AuthStatus> {
  Uint8List? _key;
  Uint8List? _salt;

  @override
  AuthStatus build() {
    Future.microtask(_init);
    return AuthStatus.unknown;
  }

  PinAuthService get _auth => ref.read(pinAuthServiceProvider);

  /// The data key for the current unlocked session.
  Uint8List get dataKey {
    final key = _key;
    if (key == null) throw StateError('Session is locked');
    return key;
  }

  Uint8List get salt {
    final salt = _salt;
    if (salt == null) throw StateError('Session is locked');
    return salt;
  }

  Future<void> _init() async {
    final hasPin = await _auth.hasPin();
    if (hasPin) {
      state = AuthStatus.locked;
      return;
    }
    // First run: show the welcome pages once before PIN setup.
    final seen = await ref
        .read(secureStorageProvider)
        .read(key: ReflectKeys.onboardingSeen);
    state = seen == null ? AuthStatus.needsOnboarding : AuthStatus.needsSetup;
  }

  /// Records that the welcome pages were seen and moves on to PIN setup.
  Future<void> completeOnboarding() async {
    await ref
        .read(secureStorageProvider)
        .write(key: ReflectKeys.onboardingSeen, value: '1');
    if (state == AuthStatus.needsOnboarding) state = AuthStatus.needsSetup;
  }

  Future<void> setup(String pin) async {
    final result = await _auth.setupPin(pin);
    _adopt(result);
  }

  Future<UnlockResult> unlock(String pin) async {
    final result = await _auth.unlock(pin);
    if (result is UnlockSuccess) _adopt(result);
    return result;
  }

  /// Biometric unlock (when enabled). Returns true on success.
  Future<bool> unlockWithBiometrics() async {
    final result = await ref.read(biometricUnlockServiceProvider).unlock();
    if (result == null) return false;
    _adopt(result);
    return true;
  }

  Future<UnlockResult> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final result = await _auth.changePin(oldPin: oldPin, newPin: newPin);
    if (result is UnlockSuccess) {
      // Keep biometric unlock working with the freshly derived key.
      await ref.read(biometricUnlockServiceProvider).refreshKey(result.key);
      _adopt(result);
    }
    return result;
  }

  /// Zeroes the in-memory key, drops decrypted photo bytes, and returns to
  /// the locked state.
  void lock() {
    _wipe();
    ref.read(attachmentServiceProvider).clearCache();
    if (state == AuthStatus.unlocked) state = AuthStatus.locked;
  }

  Future<void> eraseAll() async {
    _wipe();
    await ref.read(attachmentServiceProvider).eraseAll();
    await ref.read(reminderSchedulerProvider).cancel();
    await _auth.eraseAll();
    state = AuthStatus.needsSetup;
  }

  void _adopt(UnlockSuccess result) {
    _wipe();
    _key = result.key;
    _salt = result.salt;
    state = AuthStatus.unlocked;
  }

  void _wipe() {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _salt = null;
  }
}
