import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';
import 'package:reflect/src/features/auth/widgets/pin_entry_panel.dart';

/// Whether the biometric unlock button should appear (toggle on and a
/// wrapped key present). Cheap: checks the stored flag before any hardware.
final biometricUnlockOfferedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricUnlockServiceProvider).isEnabled(),
);

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final GlobalKey<PinEntryPanelState> _panelKey = GlobalKey();
  String? _error;
  bool _busy = false;
  Duration _cooldown = Duration.zero;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _unlock(String pin) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(sessionProvider.notifier).unlock(pin);
    if (!mounted) return;
    _panelKey.currentState?.clear();
    switch (result) {
      case UnlockSuccess():
        // Router redirect handles navigation.
        setState(() => _busy = false);
      case UnlockWrongPin(:final failedAttempts, :final cooldown):
        _panelKey.currentState?.shake();
        setState(() {
          _busy = false;
          _error = 'Wrong PIN ($failedAttempts '
              'failed attempt${failedAttempts == 1 ? '' : 's'})';
        });
        if (cooldown != null) _startCooldown(cooldown);
      case UnlockCoolingDown(:final remaining):
        setState(() => _busy = false);
        _startCooldown(remaining);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(sessionProvider.notifier).unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'Biometric unlock didn\'t work — use your PIN';
    });
  }

  void _startCooldown(Duration remaining) {
    _ticker?.cancel();
    setState(() => _cooldown = remaining);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _cooldown - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        setState(() => _cooldown = Duration.zero);
      } else {
        setState(() => _cooldown = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coolingDown = _cooldown > Duration.zero;
    final offerBiometrics =
        ref.watch(biometricUnlockOfferedProvider).valueOrNull ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.self_improvement_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Reflect', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter your PIN to unlock your journal',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                PinEntryPanel(
                  key: _panelKey,
                  enabled: !_busy && !coolingDown,
                  onSubmit: _unlock,
                ),
                if (offerBiometrics) ...[
                  const SizedBox(height: AppSpacing.sm),
                  IconButton(
                    onPressed:
                        _busy || coolingDown ? null : _unlockWithBiometrics,
                    tooltip: 'Unlock with biometrics',
                    iconSize: 32,
                    color: theme.colorScheme.primary,
                    icon: const Icon(Icons.fingerprint_rounded),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 24,
                  child: coolingDown
                      ? Text(
                          'Too many attempts. Try again in '
                          '${_cooldown.inSeconds}s',
                          style: theme.textTheme.bodySmall!
                              .copyWith(color: theme.colorScheme.error),
                        )
                      : _error != null
                          ? Text(
                              _error!,
                              style: theme.textTheme.bodySmall!
                                  .copyWith(color: theme.colorScheme.error),
                            )
                          : _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
