import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Verifies the current PIN — or, in a session opened with a fingerprint, a
/// fresh fingerprint — then re-encrypts the journal, photos and verifier with
/// a key derived from the new PIN (fresh salt). An existing recovery key is
/// replaced and the new one shown.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _busy = false;
  late final bool _withFingerprint =
      ref.read(sessionProvider.notifier).unlockedWithBiometrics;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final newPin = _newController.text;
    final confirm = _confirmController.text;

    if (newPin.length < PinAuthService.minPinLength) {
      setState(() => _error = 'New password must be at least '
          '${PinAuthService.minPinLength} characters');
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final (result, recoveryKey) =
        await ref.read(sessionProvider.notifier).changePin(
              oldPin: _withFingerprint ? null : current,
              newPin: newPin,
            );
    if (!mounted) return;

    switch (result) {
      case UnlockSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed — journal re-encrypted'),
          ),
        );
        if (recoveryKey != null) {
          await context.push(AppRoutes.recoveryKey, extra: recoveryKey);
          if (!mounted) return;
        }
        context.pop();
      case UnlockWrongPin():
        setState(() {
          _busy = false;
          _error = _withFingerprint
              ? 'Fingerprint not confirmed'
              : 'Current password is incorrect';
        });
      case UnlockCoolingDown(:final remaining):
        setState(() {
          _busy = false;
          _error = 'Too many attempts. Try again in ${remaining.inSeconds}s';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (_withFingerprint)
            Text(
              "You'll confirm with your fingerprint when you save.",
              style: AppTextStyles.bodySmall.copyWith(
                color: SuiteColors.of(context).textSecondary,
              ),
            )
          else
            AppTextField(
              label: 'Current password',
              controller: _currentController,
              obscureText: true,
              autofocus: true,
            ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'New password (6+ characters)',
            controller: _newController,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Confirm new password',
            controller: _confirmController,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: SuiteColors.of(context).negative,
                ),
              ),
            ),
          VaultButton(
            label: 'Change password',
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
