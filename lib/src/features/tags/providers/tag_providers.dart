import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';

/// All tags in use, with entry counts, sorted by count then name.
final tagCountsProvider = Provider<List<({String tag, int count})>>((ref) {
  final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
  final counts = <String, int>{};
  for (final entry in entries) {
    for (final tag in entry.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final list = [
    for (final e in counts.entries) (tag: e.key, count: e.value),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.tag.compareTo(b.tag);
    });
  return list;
});

/// Entries carrying [tag], newest first (source list is already sorted).
final entriesByTagProvider =
    Provider.family<List<JournalEntry>, String>((ref, tag) {
  final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
  return [
    for (final entry in entries)
      if (entry.tags.contains(tag)) entry,
  ];
});
