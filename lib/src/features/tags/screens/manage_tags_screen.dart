import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect/src/core/router/app_router.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/tags/providers/tag_providers.dart';

/// Browse, rename, and delete tags across the whole journal.
class ManageTagsScreen extends ConsumerWidget {
  const ManageTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagCountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tags.isEmpty
          ? const VaultEmptyState(
              icon: Icons.label_outline,
              message: 'Tags you add to entries appear here,\n'
                  'ready to browse, rename, or remove.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: tags.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = tags[index];
                return ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(item.tag),
                  subtitle: Text(
                    '${item.count} '
                    '${item.count == 1 ? 'entry' : 'entries'}',
                  ),
                  onTap: () => context.push(AppRoutes.tagTimeline(item.tag)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Rename',
                        onPressed: () => _rename(context, ref, item.tag),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () =>
                            _delete(context, ref, item.tag, item.count),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String tag,
  ) async {
    final controller = TextEditingController(text: tag);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename "$tag"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'New name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    final cleaned = next?.trim().toLowerCase();
    if (cleaned == null || cleaned.isEmpty || cleaned == tag) return;
    final changed =
        await ref.read(entriesProvider.notifier).renameTag(tag, cleaned);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Renamed on $changed ${changed == 1 ? 'entry' : 'entries'}',
          ),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String tag,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "$tag"?'),
        content: Text(
          'The tag will be removed from $count '
          '${count == 1 ? 'entry' : 'entries'}. '
          'The entries themselves are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(entriesProvider.notifier).deleteTag(tag);
  }
}
