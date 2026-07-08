import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';

/// Whether the device offers biometrics at all (drives Settings visibility).
final biometricSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricUnlockServiceProvider).isSupported(),
);

/// The user-facing toggle state. Off by default; enabling wraps the current
/// session key behind a biometric prompt, disabling wipes it.
final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
  BiometricEnabledNotifier.new,
);

final class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(biometricUnlockServiceProvider).isEnabled();

  /// Returns true when the toggle was switched on successfully.
  Future<bool> enable() async {
    final session = ref.read(sessionProvider.notifier);
    final ok =
        await ref.read(biometricUnlockServiceProvider).enable(session.dataKey);
    state = AsyncData(ok);
    return ok;
  }

  Future<void> disable() async {
    await ref.read(biometricUnlockServiceProvider).disable();
    state = const AsyncData(false);
  }
}
