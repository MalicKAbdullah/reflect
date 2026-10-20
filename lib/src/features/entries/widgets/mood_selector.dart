import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/entries/models/mood.dart';

/// Emoji scale 1–5 for picking a mood rating.
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var mood = Mood.min; mood <= Mood.max; mood++) ...[
          if (mood > Mood.min) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _MoodChip(
              mood: mood,
              isSelected: mood == selected,
              onTap: () => onChanged(mood),
            ),
          ),
        ],
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final int mood;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final color = Mood.color(mood);
    return Semantics(
      button: true,
      selected: isSelected,
      label: Mood.label(mood),
      child: ExcludeSemantics(
        child: Material(
          color: isSelected
              ? Mood.container(mood, Theme.of(context).brightness)
              : c.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
              child: Column(
                children: [
                  Text(Mood.emoji(mood), style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(
                    Mood.label(mood),
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected ? c.textPrimary : c.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
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
