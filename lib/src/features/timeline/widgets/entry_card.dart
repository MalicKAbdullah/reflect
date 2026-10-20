import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/timeline/widgets/tag_chip.dart';

/// Timeline card: mood badge, title and snippet, time, photo count and
/// tappable tags.
class EntryCard extends StatelessWidget {
  const EntryCard({
    required this.entry,
    this.onTap,
    this.onTagTap,
    super.key,
  });

  final JournalEntry entry;
  final VoidCallback? onTap;
  final ValueChanged<String>? onTagTap;

  static final DateFormat _time = DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final snippet = entry.body.replaceAll(RegExp(r'\s+'), ' ').trim();

    return VaultCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Mood.container(entry.mood, Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              Mood.emoji(entry.mood),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (entry.photoIds.isNotEmpty) ...[
                      Icon(
                        Icons.photo_outlined,
                        size: 14,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.photoIds.length}',
                        style: AppTextStyles.caption
                            .copyWith(color: c.textTertiary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      _time.format(entry.createdAt),
                      style:
                          AppTextStyles.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
                if (snippet.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: c.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.smd),
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: AppSpacing.xs + 2,
                    children: [
                      for (final tag in entry.tags.take(4))
                        TagChip(
                          tag: tag,
                          onTap: onTagTap == null ? null : () => onTagTap!(tag),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
