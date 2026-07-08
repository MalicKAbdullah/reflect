import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/screens/entry_view_screen.dart';

/// Serves fixed entries without touching session, crypto or storage.
class _FakeEntriesNotifier extends EntriesNotifier {
  _FakeEntriesNotifier(this._entries);

  final List<JournalEntry> _entries;

  @override
  Future<List<JournalEntry>> build() async => _entries;
}

void main() {
  final entry = JournalEntry(
    id: 'e1',
    title: 'A good day',
    body: 'Morning walk was **great** and *calm*.\n'
        '- coffee outside\n'
        '- called mum',
    mood: 5,
    tags: const ['grateful', 'outside'],
    createdAt: DateTime(2026, 7, 3, 9, 30),
    updatedAt: DateTime(2026, 7, 3, 9, 30),
  );

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesProvider.overrideWith(() => _FakeEntriesNotifier([entry])),
        ],
        child: const MaterialApp(
          home: EntryViewScreen(entryId: 'e1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders title, mood, tags and markdown-lite body',
      (tester) async {
    await pumpView(tester);

    expect(find.text('A good day'), findsOneWidget);
    expect(find.text('Great'), findsOneWidget); // mood label chip
    expect(find.text('😄'), findsOneWidget);
    expect(find.text('grateful'), findsOneWidget);
    expect(find.text('outside'), findsOneWidget);

    // Markdown markers are consumed, not shown literally.
    expect(find.textContaining('**'), findsNothing);

    // Bold and italic spans exist with the right styles.
    final richTexts =
        tester.widgetList<RichText>(find.byType(RichText)).toList();
    var foundBold = false;
    var foundItalic = false;
    for (final rich in richTexts) {
      rich.text.visitChildren((span) {
        if (span is TextSpan) {
          if (span.text == 'great' &&
              span.style?.fontWeight == FontWeight.w700) {
            foundBold = true;
          }
          if (span.text == 'calm' &&
              span.style?.fontStyle == FontStyle.italic) {
            foundItalic = true;
          }
        }
        return true;
      });
    }
    expect(foundBold, isTrue, reason: 'bold run should be rendered');
    expect(foundItalic, isTrue, reason: 'italic run should be rendered');

    // Bullet lines render with a bullet glyph.
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('edit action is available', (tester) async {
    await pumpView(tester);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
