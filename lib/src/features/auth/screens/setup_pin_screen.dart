import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/widgets/pin_entry_panel.dart';

/// First-run flow: choose a PIN, then confirm it.
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  final GlobalKey<PinEntryPanelState> _panelKey = GlobalKey();
  String? _firstPin;
  String? _error;
  bool _busy = false;

  Future<void> _onSubmit(String pin) async {
    _panelKey.currentState?.clear();
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _error = null;
      });
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _error = 'PINs did not match — start over';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(sessionProvider.notifier).setup(pin);
    // Router redirect takes over once the session unlocks.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirming = _firstPin != null;
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
                Text('Welcome to Reflect',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  confirming
                      ? 'Re-enter your PIN to confirm'
                      : 'Create a PIN (6+ digits).\n'
                          'It protects your journal on this device.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                PinEntryPanel(
                  key: _panelKey,
                  enabled: !_busy,
                  onSubmit: _onSubmit,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 24,
                  child: _error != null
                      ? Text(
                          _error!,
                          style: theme.textTheme.bodySmall!
                              .copyWith(color: theme.colorScheme.error),
                        )
                      : _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
