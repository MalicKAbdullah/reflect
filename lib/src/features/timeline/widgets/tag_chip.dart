import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Small pill for a tag. Tappable when [onTap] is given (opens the
/// tag-filtered timeline).
class TagChip extends StatelessWidget {
  const TagChip({required this.tag, this.onTap, super.key});

  final String tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: 3,
          ),
          child: Text(
            tag,
            style: AppTextStyles.caption.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
