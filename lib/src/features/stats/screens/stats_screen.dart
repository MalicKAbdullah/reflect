import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';
import 'package:reflect/src/features/stats/widgets/mood_distribution_bars.dart';
import 'package:reflect/src/features/stats/widgets/mood_trend_chart.dart';
import 'package:reflect/src/features/stats/widgets/weekly_bar_chart.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
    final stats = JournalStats.compute(
      entries,
      now: ref.watch(clockProvider).now(),
    );
    final theme = Theme.of(context);

    final goalProgress = ref.watch(goalProgressProvider);

    if (entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stats')),
        body: const VaultEmptyState(
          icon: Icons.insights_outlined,
          message: 'Write a few entries and your\nmood analytics appear here.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Current streak',
                  value: '${stats.currentStreak}',
                  suffix: _dayUnit(stats.currentStreak),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  label: 'Longest streak',
                  value: '${stats.longestStreak}',
                  suffix: _dayUnit(stats.longestStreak),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total words',
                  value: '${stats.totalWords}',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  label: 'Avg words / entry',
                  value: stats.avgWordsPerEntry.toStringAsFixed(0),
                ),
              ),
            ],
          ),
          if (goalProgress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Goal met (30 days)',
                    value: '${goalProgress.daysMet}',
                    suffix: 'of ${goalProgress.windowDays} days',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    label: 'Goal streak',
                    value: '${goalProgress.streak}',
                    suffix: _dayUnit(goalProgress.streak),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Mood — last 30 days', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            child: RepaintBoundary(
              child: MoodTrendChart(trend: stats.moodTrend),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Mood distribution', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            child: RepaintBoundary(
              child: MoodDistributionBars(distribution: stats.moodDistribution),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Entries per week', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          VaultCard(
            child: RepaintBoundary(
              child: WeeklyBarChart(weeks: stats.entriesPerWeek),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayUnit(int count) => count == 1 ? 'day' : 'days';
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.suffix});

  final String label;
  final String value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VaultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.numberLarge
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
              if (suffix != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(suffix!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
