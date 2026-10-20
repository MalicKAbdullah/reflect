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
  bool _unlockedWithBiometrics = false;
  bool _recoveryOfferDue = false;

  /// Whether this session was opened with a fingerprint, which then stands
  /// in for the current password when changing it (re-prompted).
  bool get unlockedWithBiometrics => _unlockedWithBiometrics;

  /// True after an unlock when no recovery key exists and none was offered;
  /// the router then shows the one-time offer.
  bool get recoveryOfferDue => _recoveryOfferDue;

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
    await _adopt(result);
  }

  Future<UnlockResult> unlock(String pin) async {
    final result = await _auth.unlock(pin);
    if (result is UnlockSuccess) await _adopt(result);
    return result;
  }

  /// Biometric unlock (when enabled). Returns true on success.
  Future<bool> unlockWithBiometrics() async {
    final result = await ref.read(biometricUnlockServiceProvider).unlock();
    if (result == null) return false;
    await _adopt(result, biometric: true);
    return true;
  }

  /// Changes the password. With [oldPin] null the session must have been
  /// opened with a fingerprint, and a fresh fingerprint is required. Returns
  /// the result and, when a recovery key existed, its replacement to show
  /// (the old one cannot follow the new data key).
  Future<(UnlockResult, String?)> changePin({
    required String? oldPin,
    required String newPin,
  }) async {
    final hadRecovery = await _auth.hasRecoveryKey();
    final UnlockResult result;
    if (oldPin == null) {
      if (!_unlockedWithBiometrics ||
          !await ref
              .read(biometricAuthProvider)
              .authenticate(reason: 'Confirm it’s you to change your password')) {
        return (const UnlockWrongPin(failedAttempts: 0), null);
      }
      result = await _auth.changePinWithKey(currentKey: dataKey, newPin: newPin);
    } else {
      result = await _auth.changePin(oldPin: oldPin, newPin: newPin);
    }
    if (result is! RekeySuccess) return (result, null);
    await _applyRekey(result);
    final recoveryKey =
        hadRecovery ? await _auth.createRecoveryKey(result.key) : null;
    return (result as UnlockResult, recoveryKey);
  }

  /// Forgotten password: [recoveryKey] unlocks and sets [newPin].
  Future<UnlockResult> resetWithRecoveryKey({
    required String recoveryKey,
    required String newPin,
  }) async {
    final result = await _auth.resetPinWithRecoveryKey(
      recoveryKey: recoveryKey,
      newPin: newPin,
    );
    if (result is RekeySuccess) await _applyRekey(result);
    return result;
  }

  /// Creates (or replaces) the recovery key for this session's data key.
  Future<String> createRecoveryKey() => _auth.createRecoveryKey(dataKey);

  /// Ends the one-time recovery-key offer.
  Future<void> finishRecoveryOffer() async {
    await _auth.markRecoveryOffered();
    _recoveryOfferDue = false;
    // Re-emit so the router leaves the offer.
    ref.notifyListeners();
  }

  /// Moves photos and the biometric key to the new data key, then adopts it.
  Future<void> _applyRekey(RekeySuccess result) async {
    await ref.read(attachmentServiceProvider).rekey(
          oldKey: result.previousKey,
          newKey: result.key,
          newSalt: result.salt,
        );
    // Keep biometric unlock working with the freshly derived key.
    await ref.read(biometricUnlockServiceProvider).refreshKey(result.key);
    final previous = result.previousKey;
    final sessionKey = _key;
    await _adopt(result, biometric: _unlockedWithBiometrics);
    if (!identical(previous, sessionKey)) {
      previous.fillRange(0, previous.length, 0);
    }
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

  Future<void> _adopt(UnlockSuccess result, {bool biometric = false}) async {
    _recoveryOfferDue = await _auth.recoveryOfferDue();
    _wipe();
    _key = result.key;
    _salt = result.salt;
    _unlockedWithBiometrics = biometric;
    state = AuthStatus.unlocked;
  }

  void _wipe() {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _salt = null;
    _unlockedWithBiometrics = false;
  }
}
