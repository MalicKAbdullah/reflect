import 'dart:math' as math;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/auth/services/pin_auth_service.dart';

/// PIN dots + numeric keypad. Collects at least [PinAuthService.minPinLength]
/// digits and calls [onSubmit] when the check key is tapped.
class PinEntryPanel extends StatefulWidget {
  const PinEntryPanel({
    required this.onSubmit,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onSubmit;
  final bool enabled;

  @override
  State<PinEntryPanel> createState() => PinEntryPanelState();
}

class PinEntryPanelState extends State<PinEntryPanel>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  void clear() => setState(() => _pin = '');

  /// Subtle horizontal shake of the PIN dots (wrong-PIN feedback).
  void shake() => _shakeController.forward(from: 0);

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _append(String digit) {
    if (!widget.enabled || _pin.length >= 12) return;
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.length < PinAuthService.minPinLength) return;
    widget.onSubmit(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        widget.enabled && _pin.length >= PinAuthService.minPinLength;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            // Damped sine: three quick swings that settle back to center.
            final dx = math.sin(t * math.pi * 6) * (1 - t) * 8;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _PinDots(count: _pin.length),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _keyRow([
            for (final digit in row)
              _Key(
                label: digit,
                onTap: widget.enabled ? () => _append(digit) : null,
              ),
          ]),
        _keyRow([
          _Key(
            icon: Icons.backspace_outlined,
            onTap: widget.enabled && _pin.isNotEmpty ? _backspace : null,
          ),
          _Key(label: '0', onTap: widget.enabled ? () => _append('0') : null),
          _Key(
            icon: Icons.check_rounded,
            emphasized: true,
            onTap: canSubmit ? _submit : null,
          ),
        ]),
      ],
    );
  }

  Widget _keyRow(List<Widget> keys) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: keys),
      );
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = count == 0 ? PinAuthService.minPinLength : count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shown; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count ? scheme.primary : Colors.transparent,
              border: Border.all(color: scheme.outline, width: 1.5),
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.onTap, this.emphasized = false});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    final color = disabled
        ? scheme.onSurface.withValues(alpha: 0.25)
        : emphasized
            ? scheme.primary
            : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 64,
            child: Center(
              child: label != null
                  ? Text(
                      label!,
                      style: AppTextStyles.h2.copyWith(color: color),
                    )
                  : Icon(icon, color: color, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
