import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/entries/models/mood.dart';

/// Preset mood tags plus the ability to add custom ones.
class TagSelector extends StatefulWidget {
  const TagSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  void _toggle(String tag) {
    final next = [...widget.selected];
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    widget.onChanged(next);
  }

  Future<void> _addCustom() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'e.g. inspired'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final cleaned = tag?.trim().toLowerCase();
    if (cleaned != null &&
        cleaned.isNotEmpty &&
        !widget.selected.contains(cleaned)) {
      widget.onChanged([...widget.selected, cleaned]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom =
        widget.selected.where((t) => !Mood.presetTags.contains(t)).toList();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tag in [...Mood.presetTags, ...custom])
          FilterChip(
            label: Text(tag),
            selected: widget.selected.contains(tag),
            onSelected: (_) => _toggle(tag),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('custom'),
          onPressed: _addCustom,
        ),
      ],
    );
  }
}
