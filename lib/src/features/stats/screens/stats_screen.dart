import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final c = SuiteColors.of(context);
    final goalProgress = ref.watch(goalProgressProvider);

    if (entries.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: AppEmptyState(
            icon: Icons.insights_outlined,
            title: 'Nothing to chart yet',
            message: 'Write a few entries and your mood analytics appear '
                'here.',
          ),
        ),
      );
    }

    final words = NumberFormat.decimalPattern().format(stats.totalWords);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Stats',
              style: AppTextStyles.h2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            HeroMetricCard(
              label: 'Words written',
              value: Text(
                words,
                style: AppTextStyles.hero.copyWith(color: c.textPrimary),
              ),
              deltaCaption: '${stats.totalEntries} '
                  '${stats.totalEntries == 1 ? 'entry' : 'entries'} in total',
              trend: [
                for (final n in JournalStats.dailyEntryCounts(
                  entries,
                  now: ref.watch(clockProvider).now(),
                  days: 30,
                ))
                  n.toDouble(),
              ],
              footer: [
                StatTile(
                  label: 'Streak',
                  value:
                      '${stats.currentStreak} ${_dayUnit(stats.currentStreak)}',
                ),
                StatTile(
                  label: 'Longest',
                  value:
                      '${stats.longestStreak} ${_dayUnit(stats.longestStreak)}',
                ),
                StatTile(
                  label: 'Avg words',
                  value: stats.avgWordsPerEntry.toStringAsFixed(0),
                ),
              ],
            ),
            if (goalProgress != null) ...[
              const SizedBox(height: AppSpacing.smd),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Goal met',
                      icon: Icons.flag_outlined,
                      value: Text(
                        '${goalProgress.daysMet}',
                        style: AppTextStyles.numberLarge
                            .copyWith(color: c.textPrimary),
                      ),
                      caption: 'of ${goalProgress.windowDays} days',
                      visual: AppProgressBar(
                        value: goalProgress.daysMet / goalProgress.windowDays,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: MetricCard(
                      label: 'Goal streak',
                      icon: Icons.local_fire_department_outlined,
                      value: Text(
                        '${goalProgress.streak}',
                        style: AppTextStyles.numberLarge
                            .copyWith(color: c.textPrimary),
                      ),
                      caption: _dayUnit(goalProgress.streak),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Mood', subtitle: 'Last 30 days'),
            VaultCard(
              child: RepaintBoundary(
                child: MoodTrendChart(trend: stats.moodTrend),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Mood distribution'),
            VaultCard(
              child: RepaintBoundary(
                child:
                    MoodDistributionBars(distribution: stats.moodDistribution),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(
              title: 'Entries per week',
              subtitle: 'Last 8 weeks',
            ),
            VaultCard(
              child: RepaintBoundary(
                child: WeeklyBarChart(weeks: stats.entriesPerWeek),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dayUnit(int count) => count == 1 ? 'day' : 'days';
}
