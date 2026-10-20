import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'On this day'),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: memories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.smd),
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
    final c = SuiteColors.of(context);
    final entry = memory.entry;
    final snippet = entry.body.replaceAll(RegExp(r'\s+'), ' ').trim();

    return SizedBox(
      width: 248,
      child: VaultCard(
        onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  Mood.emoji(entry.mood),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    memory.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelStrong.copyWith(color: c.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              entry.title.isEmpty
                  ? OnThisDaySection._monthYear.format(entry.createdAt)
                  : entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h4.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
