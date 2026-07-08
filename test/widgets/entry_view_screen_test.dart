import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

/// One text run with the style it effectively resolves to (parent styles
/// merged into children, the way rendering inherits them).
class _Run {
  _Run(this.text, this.style);
  final String text;
  final TextStyle style;
}

/// Collects every leaf text run across all RichText widgets, resolving the
/// effective (inherited) style for each.
List<_Run> _allRuns(WidgetTester tester) {
  final runs = <_Run>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final merged =
          span.style == null ? inherited : inherited.merge(span.style);
      if (span.text != null && span.text!.isNotEmpty) {
        runs.add(_Run(span.text!, merged));
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, merged);
      }
    }

    visit(rich.text, const TextStyle());
  }
  return runs;
}

void main() {
  final entry = JournalEntry(
    id: 'e1',
    title: 'A good day',
    body: '# Big heading\n\n'
        'Morning walk was **great** and *calm*.\n\n'
        '- coffee outside\n'
        '- called mum\n\n'
        'Try `flutter test` and visit [docs](https://example.com).',
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

  testWidgets('renders full markdown: heading, bold, list, code and link',
      (tester) async {
    await pumpView(tester);

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('A good day'), findsOneWidget); // title
    expect(find.text('Great'), findsOneWidget); // mood label chip
    expect(find.text('😄'), findsOneWidget);
    expect(find.text('grateful'), findsOneWidget);

    // Raw markdown markers are consumed, not shown literally.
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('# Big'), findsNothing);

    final runs = _allRuns(tester);
    bool has(bool Function(_Run) test) => runs.any(test);

    // Bold run.
    expect(
      has((r) => r.text == 'great' && r.style.fontWeight == FontWeight.w700),
      isTrue,
      reason: 'bold run should render',
    );
    // Italic run.
    expect(
      has((r) => r.text == 'calm' && r.style.fontStyle == FontStyle.italic),
      isTrue,
      reason: 'italic run should render',
    );
    // Heading text present.
    expect(has((r) => r.text == 'Big heading'), isTrue);
    // Inline code, monospace.
    expect(
      has((r) => r.text == 'flutter test' && r.style.fontFamily == 'monospace'),
      isTrue,
      reason: 'inline code should render monospace',
    );
    // Link, underlined.
    expect(
      has((r) =>
          r.text == 'docs' &&
          r.style.decoration == TextDecoration.underline),
      isTrue,
      reason: 'link should render underlined',
    );
    // Bullets rendered.
    expect(find.textContaining('coffee outside'), findsOneWidget);
  });

  testWidgets('edit action is available', (tester) async {
    await pumpView(tester);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
