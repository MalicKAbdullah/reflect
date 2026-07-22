import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/attachments/widgets/editor_photo_strip.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/entries/providers/draft_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/services/writing_prompts.dart';
import 'package:reflect/src/features/entries/widgets/markdown_entry_body.dart';
import 'package:reflect/src/features/entries/widgets/mood_selector.dart';
import 'package:reflect/src/features/entries/widgets/tag_selector.dart';

/// Create/edit screen with a daily writing prompt and debounced draft
/// autosave (in memory only; persisted encrypted on Save).
class EntryEditorScreen extends ConsumerStatefulWidget {
  const EntryEditorScreen({this.entryId, super.key});

  final String? entryId;

  bool get isNew => entryId == null;

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  static const Duration _debounce = Duration(milliseconds: 600);

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  Timer? _debounceTimer;
  int _mood = 3;
  List<String> _tags = const [];
  List<String> _photoIds = const [];

  /// Photos added in this editor session, not yet part of a saved entry.
  final List<String> _addedPhotoIds = [];
  bool _photoBusy = false;
  bool _draftSaved = false;
  bool _preview = false;

  String get _draftKey => widget.entryId ?? DraftsNotifier.newEntryKey;

  /// Wraps the current selection with [left]/[right] (e.g. ** for bold),
  /// or inserts the pair at the cursor when nothing is selected.
  void _wrapSelection(String left, String right) {
    final value = _bodyController.value;
    final sel = value.selection;
    final start = sel.start < 0 ? value.text.length : sel.start;
    final end = sel.end < 0 ? value.text.length : sel.end;
    final selected = value.text.substring(start, end);
    final newText = value.text.replaceRange(start, end, '$left$selected$right');
    _bodyController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: end + left.length + right.length,
      ),
    );
  }

  /// Prepends [prefix] to the start of the line the cursor is on.
  void _prefixLine(String prefix) {
    final value = _bodyController.value;
    final pos = value.selection.start < 0 ? 0 : value.selection.start;
    final lineStart = value.text.lastIndexOf('\n', pos - 1) + 1;
    final newText = value.text.replaceRange(lineStart, lineStart, prefix);
    _bodyController.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.entryId == null
        ? null
        : ref.read(entryByIdProvider(widget.entryId!));
    final draft = ref.read(draftsProvider)[_draftKey];

    _titleController =
        TextEditingController(text: draft?.title ?? entry?.title ?? '');
    _bodyController =
        TextEditingController(text: draft?.body ?? entry?.body ?? '');
    _mood = draft?.mood ?? entry?.mood ?? 3;
    _tags = draft?.tags ?? entry?.tags ?? const [];
    _photoIds = List.of(draft?.photoIds ?? entry?.photoIds ?? const []);

    _titleController.addListener(_scheduleDraftSave);
    _bodyController.addListener(_scheduleDraftSave);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _saveDraft);
  }

  void _saveDraft() {
    if (!mounted) return;
    ref.read(draftsProvider.notifier).save(
          _draftKey,
          EntryDraft(
            title: _titleController.text,
            body: _bodyController.text,
            mood: _mood,
            tags: _tags,
            photoIds: List.of(_photoIds),
          ),
        );
    setState(() => _draftSaved = true);
  }

  Future<void> _save() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')),
      );
      return;
    }
    final notifier = ref.read(entriesProvider.notifier);
    final title = _titleController.text.trim();
    if (widget.isNew) {
      await notifier.addEntry(
        title: title,
        body: body,
        mood: _mood,
        tags: _tags,
        photoIds: List.of(_photoIds),
      );
    } else {
      final entry = ref.read(entryByIdProvider(widget.entryId!));
      if (entry != null) {
        await notifier.updateEntry(
          entry.copyWith(
            title: title,
            body: body,
            mood: _mood,
            tags: _tags,
            photoIds: List.of(_photoIds),
          ),
        );
        // Photos removed from a saved entry are deleted only now, so
        // backing out of the edit never loses them.
        final dropped =
            entry.photoIds.where((id) => !_photoIds.contains(id)).toList();
        if (dropped.isNotEmpty) {
          await ref.read(attachmentServiceProvider).deletePhotos(dropped);
        }
      }
    }
    _addedPhotoIds.clear();
    ref.read(draftsProvider.notifier).discard(_draftKey);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(entriesProvider.notifier).deleteEntry(widget.entryId!);
    // Photos added during this edit were never saved onto the entry, so
    // the delete cascade cannot know about them.
    if (_addedPhotoIds.isNotEmpty) {
      await ref
          .read(attachmentServiceProvider)
          .deletePhotos(List.of(_addedPhotoIds));
      _addedPhotoIds.clear();
    }
    ref.read(draftsProvider.notifier).discard(_draftKey);
    if (mounted) context.pop();
  }

  Future<void> _addPhoto(ImageSource source) async {
    setState(() => _photoBusy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final session = ref.read(sessionProvider.notifier);
      final id = await ref.read(attachmentServiceProvider).importPhoto(
            original: bytes,
            key: session.dataKey,
            salt: session.salt,
          );
      if (id == null) {
        _photoSnack('That photo could not be read');
        return;
      }
      if (!mounted) {
        // Screen went away mid-import — do not leave an orphaned file.
        await ref.read(attachmentServiceProvider).deletePhoto(id);
        return;
      }
      setState(() {
        _photoIds = [..._photoIds, id];
        _addedPhotoIds.add(id);
      });
      _scheduleDraftSave();
    } catch (_) {
      _photoSnack('Could not add the photo');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto(String id) async {
    setState(() => _photoIds = _photoIds.where((p) => p != id).toList());
    _scheduleDraftSave();
    if (_addedPhotoIds.remove(id)) {
      // Never referenced by a saved entry — safe to delete right away.
      await ref.read(attachmentServiceProvider).deletePhoto(id);
    }
  }

  void _photoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = WritingPrompts.forDate(ref.watch(clockProvider).now());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New entry' : 'Edit entry'),
        actions: [
          if (_draftSaved)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Center(
                child: Text('Draft saved', style: theme.textTheme.labelSmall),
              ),
            ),
          IconButton(
            icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (widget.isNew)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(prompt, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(hintText: 'Title (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_preview) ...[
            _MarkdownToolbar(
              onBold: () => _wrapSelection('**', '**'),
              onItalic: () => _wrapSelection('*', '*'),
              onHeading: () => _prefixLine('## '),
              onBullet: () => _prefixLine('- '),
              onQuote: () => _prefixLine('> '),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _bodyController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'What is on your mind?',
                helperText: 'Markdown supported — tap the eye to preview.',
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 160),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: _bodyController.text.trim().isEmpty
                  ? Text(
                      'Nothing to preview yet.',
                      style: theme.textTheme.bodySmall,
                    )
                  : MarkdownEntryBody(
                      data: _bodyController.text,
                      baseStyle: theme.textTheme.bodyLarge!,
                    ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('How do you feel?', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          MoodSelector(
            selected: _mood,
            onChanged: (mood) {
              setState(() => _mood = mood);
              _scheduleDraftSave();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Photos', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          EditorPhotoStrip(
            photoIds: _photoIds,
            busy: _photoBusy,
            onAdd: _addPhoto,
            onRemove: _removePhoto,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Tags', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          TagSelector(
            selected: _tags,
            onChanged: (tags) {
              setState(() => _tags = tags);
              _scheduleDraftSave();
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// A compact Markdown formatting toolbar for the entry editor.
class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onHeading,
    required this.onBullet,
    required this.onQuote,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeading;
  final VoidCallback onBullet;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Bold',
          icon: const Icon(Icons.format_bold),
          onPressed: onBold,
        ),
        IconButton(
          tooltip: 'Italic',
          icon: const Icon(Icons.format_italic),
          onPressed: onItalic,
        ),
        IconButton(
          tooltip: 'Heading',
          icon: const Icon(Icons.title),
          onPressed: onHeading,
        ),
        IconButton(
          tooltip: 'Bulleted list',
          icon: const Icon(Icons.format_list_bulleted),
          onPressed: onBullet,
        ),
        IconButton(
          tooltip: 'Quote',
          icon: const Icon(Icons.format_quote),
          onPressed: onQuote,
        ),
      ],
    );
  }
}
