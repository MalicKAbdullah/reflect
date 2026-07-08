import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/timeline/screens/timeline_screen.dart';

import '../fakes/fakes.dart';

/// Serves fixed entries without touching session, crypto or storage.
class _FakeEntriesNotifier extends EntriesNotifier {
  _FakeEntriesNotifier(this._entries);

  final List<JournalEntry> _entries;

  @override
  Future<List<JournalEntry>> build() async => _entries;
}

JournalEntry entry(
  String id,
  DateTime createdAt, {
  String title = '',
  String body = 'Some reflective words',
  int mood = 4,
  List<String> tags = const [],
}) {
  return JournalEntry(
    id: id,
    title: title,
    body: body,
    mood: mood,
    tags: tags,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  Future<void> pumpTimeline(
    WidgetTester tester,
    List<JournalEntry> entries,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesProvider.overrideWith(() => _FakeEntriesNotifier(entries)),
          // Fixed date so the On This Day section stays deterministic.
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 7, 3))),
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state when there are no entries', (tester) async {
    await pumpTimeline(tester, const []);
    expect(
      find.textContaining('Your journal is a private space'),
      findsOneWidget,
    );
  });

  testWidgets('renders entries from the repository with month headers',
      (tester) async {
    await pumpTimeline(tester, [
      entry(
        'a',
        DateTime(2026, 6, 15, 9),
        title: 'Morning pages',
        body: 'Wrote three pages before coffee',
        mood: 5,
        tags: const ['energetic'],
      ),
      entry(
        'b',
        DateTime(2026, 5, 2, 21),
        title: 'Long walk',
        mood: 2,
      ),
    ]);

    // Month headers.
    expect(find.text('June 2026'), findsOneWidget);
    expect(find.text('May 2026'), findsOneWidget);

    // Entry cards with title, snippet, mood emoji and tag.
    expect(find.text('Morning pages'), findsOneWidget);
    expect(find.text('Long walk'), findsOneWidget);
    expect(find.textContaining('three pages'), findsOneWidget);
    expect(find.text('😄'), findsOneWidget);
    expect(find.text('😕'), findsOneWidget);
    expect(find.text('energetic'), findsOneWidget);
  });

  testWidgets('untitled entries fall back to a placeholder title',
      (tester) async {
    await pumpTimeline(tester, [entry('a', DateTime(2026, 6, 15))]);
    expect(find.text('Untitled'), findsOneWidget);
  });
}
