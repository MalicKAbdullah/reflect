import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Verifies the current PIN, then re-encrypts the journal and verifier with
/// a key derived from the new PIN (fresh salt).
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

    if (newPin.length < PinAuthService.minPinLength ||
        !RegExp(r'^\d+$').hasMatch(newPin)) {
      setState(() => _error = 'New PIN must be at least 6 digits');
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = 'New PINs do not match');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(sessionProvider.notifier)
        .changePin(oldPin: current, newPin: newPin);
    if (!mounted) return;

    switch (result) {
      case UnlockSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN changed — journal re-encrypted'),
          ),
        );
        context.pop();
      case UnlockWrongPin():
        setState(() {
          _busy = false;
          _error = 'Current PIN is incorrect';
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
      appBar: AppBar(title: const Text('Change PIN')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          VaultTextField(
            label: 'Current PIN',
            controller: _currentController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'New PIN (6+ digits)',
            controller: _newController,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          VaultTextField(
            label: 'Confirm new PIN',
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          VaultButton(
            label: 'Change PIN',
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
