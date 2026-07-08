import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/search/services/search_index.dart';

JournalEntry entry(
  String id,
  String body, {
  String title = '',
  List<String> tags = const [],
  DateTime? updatedAt,
}) {
  final stamp = updatedAt ?? DateTime(2026, 6, 1);
  return JournalEntry(
    id: id,
    title: title,
    body: body,
    mood: 3,
    tags: tags,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  group('tokenize', () {
    test('lowercases and splits on whitespace', () {
      expect(
        SearchIndex.tokenize('Hello World'),
        ['hello', 'world'],
      );
    });

    test('strips punctuation', () {
      expect(
        SearchIndex.tokenize("Well, it's done! (finally)... right?"),
        ['well', 'it', 's', 'done', 'finally', 'right'],
      );
    });

    test('keeps digits', () {
      expect(SearchIndex.tokenize('room 42b'), ['room', '42b']);
    });

    test('handles unicode text', () {
      expect(
        SearchIndex.tokenize('Träumen über café — 東京 rocks'),
        ['träumen', 'über', 'café', '東京', 'rocks'],
      );
    });

    test('empty and punctuation-only input yields no tokens', () {
      expect(SearchIndex.tokenize(''), isEmpty);
      expect(SearchIndex.tokenize('... !!! ???'), isEmpty);
    });
  });

  group('search basics', () {
    late SearchIndex index;

    setUp(() {
      index = SearchIndex();
      index.buildFrom([
        entry('a', 'Went for a long morning run in the park'),
        entry('b', 'Morning meditation and coffee', title: 'Calm start'),
        entry('c', 'Worked late, feeling tired but satisfied'),
      ]);
    });

    test('exact term match', () {
      final hits = index.search('meditation');
      expect(hits.map((h) => h.id), ['b']);
    });

    test('search is case-insensitive', () {
      expect(index.search('MORNING').length, 2);
    });

    test('matches title text as well as body', () {
      expect(index.search('calm').map((h) => h.id), ['b']);
    });

    test('prefix matching', () {
      expect(index.search('med').map((h) => h.id), ['b']);
      expect(index.search('morn').length, 2);
    });

    test('prefix does not match mid-word', () {
      expect(index.search('editation'), isEmpty);
    });

    test('multi-term AND semantics', () {
      expect(index.search('morning run').map((h) => h.id), ['a']);
      expect(index.search('morning meditation').map((h) => h.id), ['b']);
      expect(index.search('morning banana'), isEmpty);
    });

    test('no results for unknown term', () {
      expect(index.search('zebra'), isEmpty);
    });

    test('empty query returns nothing', () {
      expect(index.search(''), isEmpty);
      expect(index.search('   '), isEmpty);
    });

    test('tags are indexed', () {
      index.addEntry(entry('d', 'plain text', tags: ['grateful']));
      expect(index.search('grateful').map((h) => h.id), ['d']);
    });

    test('unicode terms are searchable with prefixes', () {
      index.addEntry(entry('u', 'Ein schöner Träumer in München'));
      expect(index.search('träum').map((h) => h.id), ['u']);
      expect(index.search('münch').map((h) => h.id), ['u']);
    });
  });

  group('ranking', () {
    test('higher summed term frequency ranks first', () {
      final index = SearchIndex();
      index.buildFrom([
        entry('once', 'yoga in the evening'),
        entry('thrice', 'yoga then more yoga and again yoga'),
      ]);
      final hits = index.search('yoga');
      expect(hits.map((h) => h.id), ['thrice', 'once']);
      expect(hits.first.score, 3);
      expect(hits.last.score, 1);
    });

    test('prefix accumulates frequency across matching terms', () {
      final index = SearchIndex();
      index.buildFrom([
        entry('a', 'run runner running'),
        entry('b', 'run'),
      ]);
      final hits = index.search('run');
      expect(hits.first.id, 'a');
      expect(hits.first.score, 3);
    });

    test('recency breaks score ties (newest first)', () {
      final index = SearchIndex();
      index.buildFrom([
        entry('old', 'quiet evening', updatedAt: DateTime(2026, 1, 1)),
        entry('new', 'quiet morning', updatedAt: DateTime(2026, 6, 1)),
        entry('mid', 'quiet afternoon', updatedAt: DateTime(2026, 3, 1)),
      ]);
      expect(
        index.search('quiet').map((h) => h.id),
        ['new', 'mid', 'old'],
      );
    });

    test('multi-term score sums across terms', () {
      final index = SearchIndex();
      index.buildFrom([
        entry('a', 'coffee coffee walk'),
        entry('b', 'coffee walk walk walk'),
      ]);
      final hits = index.search('coffee walk');
      // a: 2 + 1 = 3, b: 1 + 3 = 4.
      expect(hits.map((h) => h.id), ['b', 'a']);
      expect(hits.first.score, 4);
    });
  });

  group('incremental updates', () {
    test('addEntry makes new entry findable', () {
      final index = SearchIndex();
      expect(index.search('sunset'), isEmpty);
      index.addEntry(entry('a', 'watched the sunset'));
      expect(index.search('sunset').map((h) => h.id), ['a']);
      expect(index.documentCount, 1);
    });

    test('updateEntry reindexes: old terms gone, new terms found', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'gym session today'));
      index.updateEntry(entry('a', 'swimming session today'));
      expect(index.search('gym'), isEmpty);
      expect(index.search('swimming').map((h) => h.id), ['a']);
      expect(index.documentCount, 1);
    });

    test('update changes term frequency and thus ranking', () {
      final index = SearchIndex();
      index.buildFrom([
        entry('a', 'tea'),
        entry('b', 'tea tea', updatedAt: DateTime(2025)),
      ]);
      expect(index.search('tea').first.id, 'b');
      index.updateEntry(entry('a', 'tea tea tea'));
      expect(index.search('tea').first.id, 'a');
    });

    test('removeEntry removes from results and cleans postings', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'unique keyword sighting'));
      index.addEntry(entry('b', 'another day'));
      index.removeEntry('a');
      expect(index.search('unique'), isEmpty);
      expect(index.search('keyword'), isEmpty);
      expect(index.documentCount, 1);
    });

    test('removing an unknown id is a no-op', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'hello'));
      index.removeEntry('ghost');
      expect(index.search('hello').length, 1);
    });

    test('shared terms survive removal of one doc', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'shared word'));
      index.addEntry(entry('b', 'shared thought'));
      index.removeEntry('a');
      expect(index.search('shared').map((h) => h.id), ['b']);
    });

    test('buildFrom clears previous contents', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'legacy'));
      index.buildFrom([entry('b', 'fresh')]);
      expect(index.search('legacy'), isEmpty);
      expect(index.search('fresh').length, 1);
    });

    test('clear empties the index', () {
      final index = SearchIndex();
      index.addEntry(entry('a', 'something'));
      index.clear();
      expect(index.search('something'), isEmpty);
      expect(index.documentCount, 0);
    });
  });
}
