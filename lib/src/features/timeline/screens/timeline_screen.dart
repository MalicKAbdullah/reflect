import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';
import 'package:reflect/src/features/goals/widgets/goal_progress_card.dart';
import 'package:reflect/src/features/timeline/services/on_this_day.dart';
import 'package:reflect/src/features/timeline/widgets/entry_card.dart';
import 'package:reflect/src/features/timeline/widgets/on_this_day_section.dart';

/// Entries grouped by day with month headers, newest first.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  static final DateFormat _month = DateFormat.yMMMM();
  static final DateFormat _day = DateFormat.MMMEd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesProvider);
    final c = SuiteColors.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: entriesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: const [
              SkeletonRow(),
              SkeletonRow(),
              SkeletonRow(),
            ],
          ),
          error: (error, _) =>
              Center(child: Text('Could not load journal: $error')),
          data: (entries) {
            final now = ref.watch(clockProvider).now();
            final header = _Header(now: now);
            if (entries.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: header,
                  ),
                  Expanded(
                    child: AppEmptyState(
                      icon: Icons.auto_stories_outlined,
                      title: 'Your journal is a private space.',
                      message: 'Capture your first reflection.',
                      action: VaultButton(
                        label: 'Write an entry',
                        isFullWidth: false,
                        onPressed: () => context.push(AppRoutes.newEntry),
                      ),
                    ),
                  ),
                ],
              );
            }
            final stats = JournalStats.compute(entries, now: now);
            final progress = ref.watch(goalProgressProvider);
            final memories = OnThisDay.select(entries, now);
            final update = ref.watch(updateCheckProvider).valueOrNull;
            final updateDismissed = ref.watch(updateDismissedProvider);
            final leading = <Widget>[
              header,
              if (update != null && !updateDismissed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.smd),
                  child: UpdateBanner(
                    info: update,
                    onUpdate: () =>
                        ref.read(updateServiceProvider).openDownload(update),
                    onDismiss: () =>
                        ref.read(updateDismissedProvider.notifier).state = true,
                  ),
                ),
              _StreakHero(stats: stats, entries: entries, now: now),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.smd),
                  child: GoalProgressCard(progress: progress),
                ),
              if (memories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: OnThisDaySection(memories: memories),
                ),
            ];
            final items = _buildItems(entries);
            return ColoredBox(
              color: c.background,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  96,
                ),
                itemCount: leading.length + items.length,
                itemBuilder: (context, index) => index < leading.length
                    ? leading[index]
                    : items[index - leading.length].build(context),
              ),
            );
          },
        ),
      ),
    );
  }

  static List<_TimelineItem> _buildItems(List<JournalEntry> entries) {
    final items = <_TimelineItem>[];
    DateTime? currentMonth;
    DateTime? currentDay;
    for (final entry in entries) {
      final date = entry.localDate;
      final month = DateTime(date.year, date.month);
      if (month != currentMonth) {
        currentMonth = month;
        items.add(_HeaderItem(_month.format(month), isMonth: true));
        currentDay = null;
      }
      if (date != currentDay) {
        currentDay = date;
        items.add(_HeaderItem(_dayLabel(date)));
      }
      items.add(_EntryItem(entry));
    }
    return items;
  }

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return _day.format(date);
  }
}

sealed class _TimelineItem {
  Widget build(BuildContext context);
}

final class _HeaderItem extends _TimelineItem {
  _HeaderItem(this.label, {this.isMonth = false});

  final String label;
  final bool isMonth;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    if (isMonth) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: AppTextStyles.h3.copyWith(color: c.textPrimary),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: c.textSecondary),
      ),
    );
  }
}

final class _EntryItem extends _TimelineItem {
  _EntryItem(this.entry);

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: EntryCard(
        entry: entry,
        onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
        onTagTap: (tag) => context.push(AppRoutes.tagTimeline(tag)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM').format(now),
                  style: AppTextStyles.label.copyWith(color: c.textSecondary),
                ),
                Text(
                  'Journal',
                  style: AppTextStyles.h2.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.stats,
    required this.entries,
    required this.now,
  });

  final JournalStats stats;
  final List<JournalEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final streak = stats.currentStreak;
    final thisMonth = entries
        .where((e) =>
            e.localDate.year == now.year && e.localDate.month == now.month)
        .length;
    final avg = stats.averageMood;
    return HeroMetricCard(
      label: 'Writing streak',
      value: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$streak',
            style: AppTextStyles.hero.copyWith(color: c.textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            streak == 1 ? 'day' : 'days',
            style: AppTextStyles.h3.copyWith(color: c.textSecondary),
          ),
        ],
      ),
      deltaCaption: streak == 0
          ? 'Write today to start a streak'
          : 'Longest: ${stats.longestStreak} '
              '${stats.longestStreak == 1 ? 'day' : 'days'}',
      trend: [
        for (final n in JournalStats.dailyEntryCounts(entries, now: now))
          n.toDouble(),
      ],
      footer: [
        StatTile(label: 'This month', value: '$thisMonth'),
        StatTile(label: 'Entries', value: '${stats.totalEntries}'),
        StatTile(
          label: 'Avg mood',
          value: avg == null ? '-' : Mood.emoji(avg.round()),
        ),
      ],
    );
  }
}
