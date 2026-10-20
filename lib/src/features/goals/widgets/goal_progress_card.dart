import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/goals/services/goal_progress.dart';

/// Gentle daily-goal progress card shown on the Timeline.
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({required this.progress, super.key});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final goal = progress.goal;

    final headline = progress.metToday
        ? 'Goal met, nicely done'
        : 'Today: ${progress.todayValue} of ${goal.target} '
            '${goal.unitLabel}';

    return VaultCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconBadge(
            icon: progress.metToday ? Icons.check_rounded : Icons.flag_outlined,
            color: progress.metToday ? c.positive : c.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style:
                      AppTextStyles.labelStrong.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(
                  value: progress.fraction,
                  color: progress.metToday ? c.positive : c.accent,
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
                  style:
                      AppTextStyles.numberMedium.copyWith(color: c.textPrimary),
                ),
                Text(
                  progress.streak == 1 ? 'day' : 'days',
                  style: AppTextStyles.caption.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
