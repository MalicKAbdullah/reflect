import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/tags/providers/tag_providers.dart';
import 'package:reflect/src/features/timeline/widgets/entry_card.dart';

/// Timeline filtered to a single tag (reached by tapping a tag anywhere).
class TagTimelineScreen extends ConsumerWidget {
  const TagTimelineScreen({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesByTagProvider(tag));
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: entries.isEmpty
          ? const VaultEmptyState(
              icon: Icons.label_outline,
              message: 'No entries carry this tag anymore.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: EntryCard(
                    entry: entry,
                    onTap: () => context.push(AppRoutes.viewEntry(entry.id)),
                    onTagTap: (other) {
                      if (other != tag) {
                        context.push(AppRoutes.tagTimeline(other));
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
