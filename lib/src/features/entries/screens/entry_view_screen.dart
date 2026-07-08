import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/attachments/widgets/entry_photo_gallery.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/widgets/markdown_lite_text.dart';
import 'package:reflect/src/features/timeline/widgets/tag_chip.dart';

/// Read-only entry view with comfortable reading typography and
/// markdown-lite rendering (**bold**, *italic*, "- " bullets).
class EntryViewScreen extends ConsumerWidget {
  const EntryViewScreen({required this.entryId, super.key});

  final String entryId;

  static final DateFormat _date = DateFormat.yMMMMEEEEd();
  static final DateFormat _time = DateFormat.jm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryByIdProvider(entryId));
    if (entry == null) {
      if (ref.watch(entriesProvider).isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      // Deleted (or session relocked) while open — leave gracefully.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final readingStyle = AppTextStyles.body.copyWith(
      fontSize: 17,
      height: 1.65,
      color: theme.colorScheme.onSurface,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_date.format(entry.createdAt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push(AppRoutes.editEntry(entry.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _MoodRow(entry: entry, time: _time.format(entry.createdAt)),
          const SizedBox(height: AppSpacing.lg),
          if (entry.title.isNotEmpty) ...[
            Text(entry.title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.md),
          ],
          MarkdownLiteText(text: entry.body, style: readingStyle),
          if (entry.photoIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            EntryPhotoGallery(photoIds: entry.photoIds),
          ],
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in entry.tags)
                  TagChip(
                    tag: tag,
                    onTap: () => context.push(AppRoutes.tagTimeline(tag)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.entry, required this.time});

  final JournalEntry entry;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: Mood.container(entry.mood, theme.brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Mood.emoji(entry.mood),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                Mood.label(entry.mood),
                style: AppTextStyles.caption
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(time, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
