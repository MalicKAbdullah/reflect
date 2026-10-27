import 'dart:async';

import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Whether the biometric unlock button should appear. The single source of
/// truth is the persisted `biometricEnabled` flag (+ a wrapped key) — read
/// directly, never gated behind the slower hardware-capability probe. If the
/// toggle is on the button always shows, and the PIN always works too.
final biometricUnlockOfferedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricUnlockServiceProvider).isEnabled(),
);

/// The password lock, laid out by core's [LockLayout]: the Reflect tile and
/// name, the password field, Unlock and "Forgot password?", with the
/// fingerprint button low on the screen when biometric unlock is on.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final TextEditingController _password = TextEditingController();
  final FocusNode _focus = FocusNode();
  String? _error;
  int _failures = 0;

  /// A password check (Argon2) is running.
  bool _busy = false;

  /// The system fingerprint prompt is up.
  bool _prompting = false;

  /// Set once the biometric prompt has been auto-triggered (or the field
  /// focused, without biometrics) for this locked screen. Entering the
  /// locked state builds a fresh screen, so this happens exactly once per
  /// lock; the latch stops it re-firing on rebuild.
  bool _autoPrompted = false;

  /// True when the device reports no usable biometric hardware — the
  /// fingerprint button is then left out and the password takes over.
  bool _biometricUnavailable = false;

  Duration _cooldown = Duration.zero;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _password.text;
    if (_busy || _cooldown > Duration.zero) return;
    if (value.isEmpty) {
      _focus.requestFocus();
      return;
    }
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
          _failures++;
          _error = 'Wrong password ($failedAttempts '
              'failed attempt${failedAttempts == 1 ? '' : 's'}).';
        });
        if (cooldown != null) {
          _startCooldown(cooldown);
        } else {
          _focus.requestFocus();
        }
      case UnlockCoolingDown(:final remaining):
        setState(() => _busy = false);
        _startCooldown(remaining);
    }
  }

  /// Fired once, via a post-frame callback, when a locked screen with
  /// biometrics enabled first appears. When the hardware probe reports
  /// nothing usable, the fingerprint button goes and the password field
  /// takes focus instead.
  Future<void> _autoUnlock() async {
    final supported =
        await ref.read(biometricUnlockServiceProvider).isSupported();
    if (!mounted) return;
    if (!supported) {
      setState(() => _biometricUnavailable = true);
      _focus.requestFocus();
      return;
    }
    await _unlockWithBiometrics();
  }

  /// The system prompt shows its own mismatch and cancel feedback, so a
  /// failed or dismissed prompt adds nothing here; the password stays ready.
  Future<void> _unlockWithBiometrics() async {
    if (_prompting || _busy || _cooldown > Duration.zero) return;
    _prompting = true;
    setState(() => _error = null);
    await ref.read(sessionProvider.notifier).unlockWithBiometrics();
    _prompting = false;
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
    final coolingDown = _cooldown > Duration.zero;
    // A failed read of the toggle counts as "off": the password still works.
    final offered = switch (ref.watch(biometricUnlockOfferedProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => false,
      _ => null,
    };
    final biometric = (offered ?? false) && !_biometricUnavailable;

    // Exactly once on entering the locked state: start the fingerprint
    // prompt, or focus the field when there is no fingerprint unlock.
    if (offered != null && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (offered) {
          _autoUnlock();
        } else {
          _focus.requestFocus();
        }
      });
    }

    final error = coolingDown
        ? 'Too many attempts. Try again in ${formatLockCountdown(_cooldown)}.'
        : _error;

    return LockLayout(
      mark: const SuiteAppIcon(app: SuiteApp.reflect, size: 64),
      title: 'Reflect',
      bottom: biometric
          ? LockBiometricButton(onPressed: _unlockWithBiometrics)
          : null,
      children: [
        LockShake(
          trigger: _failures,
          child: AppTextField(
            controller: _password,
            focusNode: _focus,
            label: 'Password',
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.go,
            errorText: error,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: LockLayout.gap),
        VaultButton(
          label: 'Unlock',
          isLoading: _busy,
          onPressed: coolingDown ? null : _submit,
        ),
        // Hidden while typing so it is never cut in half by the keyboard
        // edge on small phones; it returns when the keyboard closes.
        if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
          const SizedBox(height: AppSpacing.sm),
          LockTextLink(
            label: 'Forgot password?',
            onPressed: _busy ? null : () => context.go(AppRoutes.recover),
          ),
        ],
      ],
    );
  }
}
