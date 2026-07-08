import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/search/services/search_index.dart';

/// Session-scoped inverted index. Populated after unlock by
/// [EntriesNotifier.build] and kept in sync incrementally.
final searchIndexProvider = Provider<SearchIndex>((ref) => SearchIndex());

final searchQueryProvider = StateProvider<String>((_) => '');

final class SearchResult {
  const SearchResult({required this.entry, required this.score});

  final JournalEntry entry;
  final int score;
}

final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  // Depend on entries so results refresh when the journal changes.
  final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
  if (query.isEmpty) return const [];

  final byId = {for (final e in entries) e.id: e};
  return ref
      .watch(searchIndexProvider)
      .search(query)
      .map((hit) {
        final entry = byId[hit.id];
        return entry == null
            ? null
            : SearchResult(entry: entry, score: hit.score);
      })
      .whereType<SearchResult>()
      .toList();
});
