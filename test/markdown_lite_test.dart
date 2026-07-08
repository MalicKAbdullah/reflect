import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/services/markdown_lite.dart';

void main() {
  group('inline parsing', () {
    test('plain text passes through untouched', () {
      expect(
        MarkdownLite.parseInline('just words'),
        [const MdSpan('just words')],
      );
    });

    test('bold runs are detected', () {
      expect(MarkdownLite.parseInline('a **bold** b'), const [
        MdSpan('a '),
        MdSpan('bold', bold: true),
        MdSpan(' b'),
      ]);
    });

    test('italic runs are detected', () {
      expect(MarkdownLite.parseInline('a *slanted* b'), const [
        MdSpan('a '),
        MdSpan('slanted', italic: true),
        MdSpan(' b'),
      ]);
    });

    test('bold nests italic', () {
      expect(MarkdownLite.parseInline('**bold *both* bold**'), const [
        MdSpan('bold ', bold: true),
        MdSpan('both', bold: true, italic: true),
        MdSpan(' bold', bold: true),
      ]);
    });

    test('italic nests bold', () {
      expect(MarkdownLite.parseInline('*a **ab** a*'), const [
        MdSpan('a ', italic: true),
        MdSpan('ab', bold: true, italic: true),
        MdSpan(' a', italic: true),
      ]);
    });

    test('unclosed markers render literally', () {
      expect(
        MarkdownLite.parseInline('half **open'),
        [const MdSpan('half **open')],
      );
      expect(
        MarkdownLite.parseInline('lonely * star'),
        [const MdSpan('lonely * star')],
      );
    });

    test('empty emphasis renders literally', () {
      expect(MarkdownLite.parseInline('****'), [const MdSpan('****')]);
      expect(MarkdownLite.parseInline('**'), [const MdSpan('**')]);
    });

    test('italic never closes on half of a bold marker', () {
      // "*a**" — the ** is not a valid closer for the single *.
      expect(
        MarkdownLite.parseInline('*a**'),
        [const MdSpan('*a**')],
      );
    });

    test('multiple runs in one line', () {
      expect(MarkdownLite.parseInline('**a** and *b*'), const [
        MdSpan('a', bold: true),
        MdSpan(' and '),
        MdSpan('b', italic: true),
      ]);
    });

    test('empty string yields no spans', () {
      expect(MarkdownLite.parseInline(''), isEmpty);
    });
  });

  group('block parsing', () {
    test('lines starting with "- " become bullets', () {
      final lines = MarkdownLite.parse('intro\n- first\n- **second**');
      expect(lines, hasLength(3));
      expect(lines[0].bullet, isFalse);
      expect(lines[1].bullet, isTrue);
      expect(lines[1].spans, [const MdSpan('first')]);
      expect(lines[2].bullet, isTrue);
      expect(lines[2].spans, [const MdSpan('second', bold: true)]);
    });

    test('dash without trailing space is not a bullet', () {
      final lines = MarkdownLite.parse('-not a bullet');
      expect(lines.single.bullet, isFalse);
      expect(lines.single.spans, [const MdSpan('-not a bullet')]);
    });

    test('blank lines are preserved as empty lines', () {
      final lines = MarkdownLite.parse('a\n\nb');
      expect(lines, hasLength(3));
      expect(lines[1].spans, isEmpty);
    });
  });
}
