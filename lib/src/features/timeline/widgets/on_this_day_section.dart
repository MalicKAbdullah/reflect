import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/timeline/services/on_this_day.dart';

/// "On this day" memories: horizontally scrollable cards for entries
/// written on today's date in earlier months and years.
class OnThisDaySection extends StatelessWidget {
  const OnThisDaySection({required this.memories, super.key});

  final List<OnThisDayEntry> memories;

  static final DateFormat _monthYear = DateFormat.yMMMM();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'ON THIS DAY',
                style: AppTextStyles.overline
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: memories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _MemoryCard(memory: memories[index]),
          ),
        ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory});

  final OnThisDayEntry memory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = memory.entry;
    final snippet = entry.body.replaceAll(RegExp(r'\s+'), ' ').trim();

    return SizedBox(
      width: 232,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        child: InkWell(
          onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      Mood.emoji(entry.mood),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: Text(
                        memory.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.title.isEmpty
                      ? OnThisDaySection._monthYear.format(entry.createdAt)
                      : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
