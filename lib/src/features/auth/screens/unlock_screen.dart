import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Whether the biometric unlock button should appear. The single source of
/// truth is the persisted `biometricEnabled` flag (+ a wrapped key) — read
/// directly, never gated behind the slower hardware-capability probe. If the
/// toggle is on the button always shows, and the PIN always works too.
final biometricUnlockOfferedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricUnlockServiceProvider).isEnabled(),
);

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final TextEditingController _password = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Set once the biometric prompt has been auto-triggered for this locked
  /// screen. Entering the locked state builds a fresh screen, so the prompt
  /// fires exactly once per lock; this latch stops it re-firing on rebuild.
  bool _autoPrompted = false;

  /// True when the device reports no usable biometric hardware — we then
  /// show a small inline note and quietly fall back to the PIN.
  bool _biometricUnavailable = false;

  Duration _cooldown = Duration.zero;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _password.text;
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(sessionProvider.notifier).unlock(value);
    if (!mounted) return;
    switch (result) {
      case UnlockSuccess():
        // Router redirect handles navigation.
        _password.clear();
        setState(() => _busy = false);
      case UnlockWrongPin(:final failedAttempts, :final cooldown):
        _password.clear();
        setState(() {
          _busy = false;
          _error = 'Wrong password ($failedAttempts '
              'failed attempt${failedAttempts == 1 ? '' : 's'})';
        });
        if (cooldown != null) _startCooldown(cooldown);
      case UnlockCoolingDown(:final remaining):
        setState(() => _busy = false);
        _startCooldown(remaining);
    }
  }

  /// Fired once, via a post-frame callback, when a locked screen with
  /// biometrics enabled first appears. Skips (and shows a note) when the
  /// hardware probe reports nothing usable, so the PIN takes over.
  Future<void> _autoUnlock() async {
    final supported =
        await ref.read(biometricUnlockServiceProvider).isSupported();
    if (!mounted) return;
    if (!supported) {
      setState(() => _biometricUnavailable = true);
      return;
    }
    await _unlockWithBiometrics(auto: true);
  }

  Future<void> _unlockWithBiometrics({bool auto = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(sessionProvider.notifier).unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _busy = false;
      // On an auto attempt the user may simply have dismissed the prompt —
      // stay quiet and let them retry or use the PIN. A manual tap that
      // fails gets a gentle nudge toward the PIN.
      if (!ok && !auto) {
        _error = "Biometric unlock didn't work — use your password";
      }
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
    final c = SuiteColors.of(context);
    final coolingDown = _cooldown > Duration.zero;
    final offerBiometrics =
        ref.watch(biometricUnlockOfferedProvider).valueOrNull ?? false;

    // Auto-trigger the prompt exactly once on entering the locked state.
    if (offerBiometrics && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoUnlock();
      });
    }

    final status = coolingDown
        ? 'Too many attempts. Try again in ${_cooldown.inSeconds}s'
        : _error;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SuiteAppIcon(app: SuiteApp.reflect, size: 64),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Reflect',
                          style:
                              AppTextStyles.h1.copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Enter your password to unlock your journal',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body
                              .copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          obscureText: true,
                          enabled: !_busy && !coolingDown,
                          autofocus: true,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        VaultButton(
                          label: 'Unlock',
                          onPressed: _busy || coolingDown ? null : _submit,
                        ),
                        if (offerBiometrics) ...[
                          const SizedBox(height: AppSpacing.sm),
                          VaultButton(
                            label: 'Use fingerprint',
                            icon: Icons.fingerprint_rounded,
                            variant: VaultButtonVariant.secondary,
                            onPressed: _busy || coolingDown
                                ? null
                                : () => _unlockWithBiometrics(),
                          ),
                          if (_biometricUnavailable)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.sm),
                              child: Text(
                                'Biometric hardware is unavailable. '
                                'Use your password.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: c.textSecondary),
                              ),
                            ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 24,
                          child: status != null
                              ? Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: c.negative),
                                )
                              : _busy
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: SuiteEndorsement(),
            ),
          ],
        ),
      ),
    );
  }
}
