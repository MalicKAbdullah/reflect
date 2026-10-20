import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/biometric_providers.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// Re-confirms the owner before a secret is shown or replaced (backup
/// passphrase, recovery key): a fresh fingerprint when fingerprint unlock is
/// on, otherwise — or if it fails — the password, under the unlock cooldown.
Future<bool> confirmOwner(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final biometric = await ref.read(biometricEnabledProvider.future);
  if (biometric &&
      await ref.read(biometricAuthProvider).authenticate(reason: reason)) {
    return true;
  }
  if (!context.mounted) return false;
  final controller = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(reason),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Your password'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (password == null || password.isEmpty) return false;
  final result = await ref.read(pinAuthServiceProvider).unlock(password);
  if (result is UnlockSuccess) {
    result.key.fillRange(0, result.key.length, 0);
    return true;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (result) {
            UnlockCoolingDown(:final remaining) =>
              'Too many attempts. Try again in ${remaining.inSeconds}s',
            _ => 'Incorrect password',
          },
        ),
      ),
    );
  }
  return false;
}
