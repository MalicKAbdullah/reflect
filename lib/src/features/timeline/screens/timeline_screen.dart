import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/goals/providers/goal_providers.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load journal: $error')),
        data: (entries) {
          if (entries.isEmpty) {
            return VaultEmptyState(
              icon: Icons.auto_stories_outlined,
              message: 'Your journal is a private space.\n'
                  'Capture your first reflection.',
              action: VaultButton(
                label: 'Write an entry',
                isFullWidth: false,
                onPressed: () => context.push(AppRoutes.newEntry),
              ),
            );
          }
          final progress = ref.watch(goalProgressProvider);
          final memories = OnThisDay.select(
            entries,
            ref.watch(clockProvider).now(),
          );
          final leading = <Widget>[
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: GoalProgressCard(progress: progress),
              ),
            if (memories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: OnThisDaySection(memories: memories),
              ),
          ];
          final items = _buildItems(entries);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96,
            ),
            itemCount: leading.length + items.length,
            itemBuilder: (context, index) => index < leading.length
                ? leading[index]
                : items[index - leading.length].build(context),
          );
        },
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: isMonth ? AppSpacing.lg : AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: isMonth
            ? theme.textTheme.headlineMedium
            : theme.textTheme.labelSmall!.copyWith(letterSpacing: 0.8),
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
