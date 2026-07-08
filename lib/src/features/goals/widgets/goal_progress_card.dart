import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/goals/services/goal_progress.dart';

/// Gentle daily-goal progress strip shown at the top of the Timeline.
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({required this.progress, super.key});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = progress.goal;

    final headline = progress.metToday
        ? 'Goal met — nicely done'
        : 'Today: ${progress.todayValue} of ${goal.target} '
            '${goal.unitLabel}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Row(
        children: [
          Icon(
            progress.metToday
                ? Icons.check_circle_rounded
                : Icons.flag_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: AppTextStyles.caption),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 5,
                    backgroundColor: scheme.outline.withValues(alpha: 0.35),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ],
            ),
          ),
          if (progress.streak > 0) ...[
            const SizedBox(width: AppSpacing.md),
            Column(
              children: [
                Text(
                  '${progress.streak}',
                  style: AppTextStyles.number.copyWith(color: scheme.primary),
                ),
                Text(
                  progress.streak == 1 ? 'day' : 'days',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
