import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/timeline/widgets/tag_chip.dart';

/// Timeline card: mood accent edge, emoji chip, title/snippet, time and
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
    final theme = Theme.of(context);
    final snippet = entry.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final moodColor = Mood.color(entry.mood);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: moodColor, width: 3)),
        ),
        child: VaultCard(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Mood.container(entry.mood, theme.brightness),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
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
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (entry.photoIds.isNotEmpty) ...[
                          Icon(
                            Icons.photo_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${entry.photoIds.length}',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          _time.format(entry.createdAt),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.bodySmall!.copyWith(height: 1.45),
                      ),
                    ],
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final tag in entry.tags.take(4))
                            TagChip(
                              tag: tag,
                              onTap: onTagTap == null
                                  ? null
                                  : () => onTagTap!(tag),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
