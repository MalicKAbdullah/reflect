import 'dart:async';

import 'package:core_crypto/core_crypto.dart';
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

/// "Forgot password?": the recovery key unwraps the journal key, which is
/// re-secured under a new password. The router leaves this screen once the
/// session unlocks.
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});

  @override
  ConsumerState<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends ConsumerState<RecoverScreen> {
  final _key = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final Future<bool> _hasKey =
      ref.read(pinAuthServiceProvider).hasRecoveryKey();
  String? _error;
  int _failures = 0;
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String? problem;
    if (RecoveryKey.normalize(_key.text) == null) {
      problem = 'A recovery key has ${RecoveryKey.length} letters and '
          'numbers, like XXXX-XXXX-…';
    } else if (_password.text.length < PinAuthService.minPinLength) {
      problem = 'New password must be at least '
          '${PinAuthService.minPinLength} characters';
    } else if (_password.text != _confirm.text) {
      problem = 'New passwords do not match';
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() {
        _error = problem;
        _failures++;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(sessionProvider.notifier).resetWithRecoveryKey(
              recoveryKey: _key.text,
              newPin: _password.text,
            );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result is! UnlockSuccess) _failures++;
      _error = switch (result) {
        UnlockSuccess() => null,
        UnlockWrongPin(:final cooldown) => cooldown == null
            ? 'That recovery key is not right.'
            : 'That recovery key is not right. Try again in '
                '${formatLockCountdown(cooldown)}.',
        UnlockCoolingDown(:final remaining) =>
          'Too many attempts. Try again in ${formatLockCountdown(remaining)}.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return LockLayout(
      mark: const SuiteAppIcon(app: SuiteApp.reflect, size: 64),
      title: 'Reflect',
      message: 'Reset your password',
      children: [
        FutureBuilder<bool>(
          future: _hasKey,
          builder: (context, snapshot) {
            final hasKey = snapshot.data;
            if (hasKey == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasKey
                      ? 'Enter the recovery key you saved, then choose a new '
                          'password. Your journal and photos stay as they are.'
                      : 'No recovery key was set up, so a forgotten password '
                          'cannot be reset. Unlock with your fingerprint, then '
                          'create a recovery key in Settings.',
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
                ),
                if (hasKey) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _key,
                    label: 'Recovery key',
                    hint: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                    monospace: true,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: LockLayout.gap),
                  AppTextField(
                    controller: _password,
                    label: 'New password (6+ characters)',
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: LockLayout.gap),
                  LockShake(
                    trigger: _failures,
                    child: AppTextField(
                      controller: _confirm,
                      label: 'Confirm new password',
                      obscureText: true,
                      errorText: _error,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(height: LockLayout.gap),
                  VaultButton(
                    label: 'Reset and unlock',
                    isLoading: _busy,
                    onPressed: _submit,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                LockTextLink(
                  label: 'Back to unlock',
                  onPressed: _busy ? null : () => context.go(AppRoutes.unlock),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The one-time offer after an unlock (or first setup) with no recovery
/// key: create one now, or later from Settings.
class RecoveryOfferScreen extends ConsumerStatefulWidget {
  const RecoveryOfferScreen({super.key});

  @override
  ConsumerState<RecoveryOfferScreen> createState() =>
      _RecoveryOfferScreenState();
}

class _RecoveryOfferScreenState extends ConsumerState<RecoveryOfferScreen> {
  String? _key;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    final key = await ref.read(sessionProvider.notifier).createRecoveryKey();
    if (mounted) setState(() => _key = key);
  }

  void _finish() =>
      unawaited(ref.read(sessionProvider.notifier).finishRecoveryOffer());

  @override
  Widget build(BuildContext context) {
    final key = _key;
    if (key != null) {
      return RecoveryKeyView(
        recoveryKey: key,
        appName: 'Reflect',
        onDone: _finish,
      );
    }
    final c = SuiteColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(Icons.key_rounded, size: 40, color: c.accent),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Set up a recovery key',
                style: AppTextStyles.h2.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A recovery key lets you reset your password if you forget '
                'it and your fingerprint is not working. Without one, a '
                'forgotten password means the journal cannot be opened.',
                style: AppTextStyles.body.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              VaultButton(
                label: 'Create recovery key',
                isLoading: _busy,
                onPressed: _busy ? null : _create,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('Not now — I can do this in Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
