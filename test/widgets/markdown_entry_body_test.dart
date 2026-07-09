import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/widgets/markdown_entry_body.dart';

/// One text run with the effective (inherited) style it resolves to.
class _Run {
  _Run(this.text, this.style);
  final String text;
  final TextStyle style;
}

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
  Future<void> pump(WidgetTester tester, String data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownEntryBody(
            data: data,
            baseStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every core markdown feature', (tester) async {
    await pump(
      tester,
      '# Heading\n\n'
      'A **bold** and *italic* line with `code` and [docs](https://x.com).\n\n'
      '- bullet one\n'
      '- bullet two\n\n'
      '1. first\n'
      '2. second\n\n'
      '- [x] done task\n'
      '- [ ] open task\n\n'
      '> a wise quote\n\n'
      '```\nprint(fenced);\n```\n\n'
      '---\n',
    );

    final runs = _allRuns(tester);
    bool has(bool Function(_Run) t) => runs.any(t);

    // Inline styling.
    expect(has((r) => r.text == 'bold' && r.style.fontWeight == FontWeight.w700),
        isTrue);
    expect(
        has((r) => r.text == 'italic' && r.style.fontStyle == FontStyle.italic),
        isTrue);
    expect(has((r) => r.text == 'code' && r.style.fontFamily == 'monospace'),
        isTrue);
    expect(
        has((r) =>
            r.text == 'docs' &&
            r.style.decoration == TextDecoration.underline),
        isTrue);

    // Structure.
    expect(has((r) => r.text == 'Heading'), isTrue);
    expect(find.textContaining('bullet one'), findsOneWidget);
    expect(find.textContaining('first'), findsWidgets); // ordered item text
    expect(find.text('1.'), findsOneWidget); // ordered marker
    expect(find.text('2.'), findsOneWidget);
    expect(find.textContaining('a wise quote'), findsOneWidget);
    expect(has((r) => r.text.contains('print(fenced);') &&
        r.style.fontFamily == 'monospace'), isTrue);

    // Task list checkboxes.
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);

    // Horizontal rule.
    expect(find.byType(Divider), findsOneWidget);

    // Raw markers never leak through.
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('# Heading'), findsNothing);
  });

  testWidgets('empty body renders nothing to read', (tester) async {
    await pump(tester, '   ');
    expect(_allRuns(tester), isEmpty);
  });
}
