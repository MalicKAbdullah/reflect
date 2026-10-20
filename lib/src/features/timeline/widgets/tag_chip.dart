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
    final c = SuiteColors.of(context);
    return Material(
      color: c.surfaceAlt,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: 4,
          ),
          child: Text(
            tag,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}
