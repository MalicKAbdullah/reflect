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
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var mood = Mood.min; mood <= Mood.max; mood++)
          _MoodChip(
            mood: mood,
            isSelected: mood == selected,
            onTap: () => onChanged(mood),
            theme: theme,
          ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  final int mood;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: Mood.label(mood),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Mood.color(mood).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
            border: Border.all(
              color: isSelected ? Mood.color(mood) : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              Text(Mood.emoji(mood), style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 2),
              Text(
                Mood.label(mood),
                style: theme.textTheme.labelSmall!.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
