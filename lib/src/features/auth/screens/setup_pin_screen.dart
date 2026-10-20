import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// First-run flow: choose a password, then confirm it. The password derives
/// the encryption key for the journal, so it is never stored.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pw = _password.text;
    if (pw.length < PinAuthService.minPinLength) {
      setState(() => _error = 'Use at least ${PinAuthService.minPinLength} '
          'characters.');
      return;
    }
    if (pw != _confirm.text) {
      setState(() => _error = 'Passwords did not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(sessionProvider.notifier).setup(pw);
    // Router redirect takes over once the session unlocks.
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SuiteAppIcon(app: SuiteApp.reflect, size: 56),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome to Reflect',
                    style: AppTextStyles.h1.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Create a password (6+ characters). It encrypts your '
                    'journal on this device and cannot be recovered. Pick '
                    'something you will remember.',
                    style: AppTextStyles.body.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _password,
                    label: 'Password',
                    obscureText: true,
                    autofocus: true,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: AppSpacing.smd),
                  AppTextField(
                    controller: _confirm,
                    label: 'Confirm password',
                    obscureText: true,
                    enabled: !_busy,
                    errorText: _error,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  VaultButton(
                    label: 'Create password',
                    isLoading: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
