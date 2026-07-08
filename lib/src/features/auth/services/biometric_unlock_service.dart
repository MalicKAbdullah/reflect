import 'dart:convert';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:reflect/src/core/interfaces/biometric_auth.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Optional biometric unlock (off by default).
///
/// Enabling stores the current data key in platform secure storage
/// (Keychain / EncryptedSharedPreferences); unlocking requires a successful
/// biometric prompt before the key is read back and validated against the
/// PIN verifier. Disabling wipes the stored key. The PIN always works.
final class BiometricUnlockService {
  BiometricUnlockService({
    required ISecureStorage storage,
    required IBiometricAuth biometric,
    required PinAuthService pinAuth,
  })  : _storage = storage,
        _biometric = biometric,
        _pinAuth = pinAuth;

  final ISecureStorage _storage;
  final IBiometricAuth _biometric;
  final PinAuthService _pinAuth;

  static const String _unlockReason = 'Unlock your journal';
  static const String _enableReason = 'Confirm to enable biometric unlock';

  /// Whether the device can offer biometric unlock at all.
  Future<bool> isSupported() => _biometric.isAvailable();

  /// Whether the toggle is on and a wrapped key exists.
  Future<bool> isEnabled() async {
    final flag = await _storage.read(key: ReflectKeys.biometricEnabled);
    if (flag != 'true') return false;
    return await _storage.read(key: ReflectKeys.biometricKey) != null;
  }

  /// Turns biometric unlock on for the current session key. Requires a
  /// successful biometric prompt first. Returns true on success.
  Future<bool> enable(Uint8List sessionKey) async {
    if (!await _biometric.isAvailable()) return false;
    if (!await _biometric.authenticate(reason: _enableReason)) return false;
    await _storage.write(
      key: ReflectKeys.biometricKey,
      value: base64Encode(sessionKey),
    );
    await _storage.write(key: ReflectKeys.biometricEnabled, value: 'true');
    return true;
  }

  /// Turns biometric unlock off and wipes the stored key.
  Future<void> disable() async {
    await _storage.delete(key: ReflectKeys.biometricKey);
    await _storage.delete(key: ReflectKeys.biometricEnabled);
  }

  /// Re-wraps the stored key after a PIN change so biometric unlock keeps
  /// working with the newly derived key.
  Future<void> refreshKey(Uint8List newKey) async {
    if (!await isEnabled()) return;
    await _storage.write(
      key: ReflectKeys.biometricKey,
      value: base64Encode(newKey),
    );
  }

  /// Runs the biometric prompt and, on success, restores and validates the
  /// data key. Returns null when the prompt fails, biometrics are disabled,
  /// or the stored key no longer matches the verifier (e.g. stale).
  Future<UnlockSuccess?> unlock() async {
    if (!await isEnabled()) return null;
    if (!await _biometric.authenticate(reason: _unlockReason)) return null;

    final rawKey = await _storage.read(key: ReflectKeys.biometricKey);
    final salt = await _pinAuth.currentSalt();
    if (rawKey == null || salt == null) return null;

    final key = Uint8List.fromList(base64Decode(rawKey));
    if (!await _pinAuth.verifyKey(key)) {
      // Stale key (PIN changed without refresh) — drop it defensively.
      await disable();
      return null;
    }
    await _pinAuth.resetAttempts();
    return UnlockSuccess(key: key, salt: salt);
  }
}
