import 'dart:collection';

import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// A ranked search hit: the entry id plus its relevance score.
final class SearchHit {
  const SearchHit({required this.id, required this.score});

  final String id;
  final int score;
}

/// Pure-Dart in-memory inverted index over journal entries.
///
/// - Tokenization: lowercase, unicode letters/digits only (punctuation
///   stripped).
/// - Query terms are matched as prefixes ("med" matches "meditation").
/// - Multiple terms combine with AND semantics.
/// - Results are ranked by summed term frequency, with recency
///   (updatedAt, newest first) as the tiebreak.
///
/// The index updates incrementally on entry create/update/delete.
final class SearchIndex {
  /// term -> (docId -> frequency). Sorted keys make prefix scans cheap.
  final SplayTreeMap<String, Map<String, int>> _postings = SplayTreeMap();

  /// docId -> (term -> frequency), kept so a doc can be removed/updated.
  final Map<String, Map<String, int>> _docTerms = {};

  /// docId -> updatedAt, used for the recency tiebreak.
  final Map<String, DateTime> _docUpdatedAt = {};

  static final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  /// Splits [text] into lowercase word tokens, stripping punctuation.
  static List<String> tokenize(String text) => _wordPattern
      .allMatches(text.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();

  int get documentCount => _docTerms.length;

  void buildFrom(Iterable<JournalEntry> entries) {
    clear();
    entries.forEach(addEntry);
  }

  void addEntry(JournalEntry entry) {
    if (_docTerms.containsKey(entry.id)) {
      removeEntry(entry.id);
    }
    final frequencies = <String, int>{};
    for (final token in tokenize('${entry.title} ${entry.body}')) {
      frequencies[token] = (frequencies[token] ?? 0) + 1;
    }
    for (final tag in entry.tags) {
      for (final token in tokenize(tag)) {
        frequencies[token] = (frequencies[token] ?? 0) + 1;
      }
    }
    frequencies.forEach((term, freq) {
      _postings.putIfAbsent(term, () => {})[entry.id] = freq;
    });
    _docTerms[entry.id] = frequencies;
    _docUpdatedAt[entry.id] = entry.updatedAt;
  }

  void updateEntry(JournalEntry entry) => addEntry(entry);

  void removeEntry(String id) {
    final terms = _docTerms.remove(id);
    _docUpdatedAt.remove(id);
    if (terms == null) return;
    for (final term in terms.keys) {
      final docs = _postings[term];
      if (docs == null) continue;
      docs.remove(id);
      if (docs.isEmpty) _postings.remove(term);
    }
  }

  void clear() {
    _postings.clear();
    _docTerms.clear();
    _docUpdatedAt.clear();
  }

  /// Runs a prefix-matched, multi-term AND query and returns ranked hits.
  List<SearchHit> search(String query) {
    final terms = tokenize(query);
    if (terms.isEmpty) return const [];

    Map<String, int>? combined;
    for (final term in terms) {
      final matches = _docsForPrefix(term);
      if (matches.isEmpty) return const [];
      if (combined == null) {
        combined = matches;
      } else {
        // AND: keep only docs present for every term; sum scores.
        final next = <String, int>{};
        matches.forEach((doc, score) {
          final existing = combined![doc];
          if (existing != null) next[doc] = existing + score;
        });
        if (next.isEmpty) return const [];
        combined = next;
      }
    }

    final hits = combined!.entries
        .map((e) => SearchHit(id: e.key, score: e.value))
        .toList();
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final aDate = _docUpdatedAt[a.id];
      final bDate = _docUpdatedAt[b.id];
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return hits;
  }

  /// Accumulated frequency per doc for every indexed term starting with
  /// [prefix]. Uses the sorted key order for an efficient range scan.
  Map<String, int> _docsForPrefix(String prefix) {
    final result = <String, int>{};
    void accumulate(String term) {
      _postings[term]!.forEach((doc, freq) {
        result[doc] = (result[doc] ?? 0) + freq;
      });
    }

    if (_postings.containsKey(prefix)) accumulate(prefix);
    var term = _postings.firstKeyAfter(prefix);
    while (term != null && term.startsWith(prefix)) {
      accumulate(term);
      term = _postings.firstKeyAfter(term);
    }
    return result;
  }
}
