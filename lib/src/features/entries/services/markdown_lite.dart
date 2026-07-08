import 'package:flutter/foundation.dart';

/// One styled run of text within a line.
@immutable
final class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(text, bold, italic);

  @override
  String toString() =>
      'MdSpan("$text"${bold ? ', bold' : ''}${italic ? ', italic' : ''})';
}

/// One rendered line: either a paragraph line or a bullet item.
@immutable
final class MdLine {
  const MdLine(this.spans, {this.bullet = false});

  final List<MdSpan> spans;
  final bool bullet;
}

/// Tiny markdown subset used when *viewing* entries (editing stays plain
/// text): `**bold**`, `*italic*`, and lines starting with `- ` as bullets.
///
/// Unclosed markers render literally, `**` binds before `*`, and bold can
/// nest italic (and vice versa). Pure Dart, no dependencies.
abstract final class MarkdownLite {
  static List<MdLine> parse(String text) {
    final lines = <MdLine>[];
    for (final rawLine in text.split('\n')) {
      final isBullet = rawLine.startsWith('- ');
      final content = isBullet ? rawLine.substring(2) : rawLine;
      lines.add(
        MdLine(parseInline(content), bullet: isBullet),
      );
    }
    return lines;
  }

  /// Parses `**bold**` / `*italic*` runs in a single line.
  @visibleForTesting
  static List<MdSpan> parseInline(
    String text, {
    bool bold = false,
    bool italic = false,
  }) {
    final spans = <MdSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(MdSpan(buffer.toString(), bold: bold, italic: italic));
      buffer.clear();
    }

    var i = 0;
    while (i < text.length) {
      final isDouble = !bold && text.startsWith('**', i);
      final isSingle =
          !isDouble && !italic && text[i] == '*' && !text.startsWith('**', i);

      if (isDouble || isSingle) {
        final marker = isDouble ? '**' : '*';
        final start = i + marker.length;
        final end = _findClosing(text, start, marker);
        if (end != -1 && end > start) {
          flush();
          spans.addAll(parseInline(
            text.substring(start, end),
            bold: bold || isDouble,
            italic: italic || isSingle,
          ));
          i = end + marker.length;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    flush();
    return spans;
  }

  /// Index of the closing [marker] at or after [from], or -1. A `*` search
  /// skips `**` pairs so italic never closes on half of a bold marker.
  static int _findClosing(String text, int from, String marker) {
    var i = from;
    while (i <= text.length - marker.length) {
      if (marker == '*' && text.startsWith('**', i)) {
        i += 2;
        continue;
      }
      if (text.startsWith(marker, i)) return i;
      i++;
    }
    return -1;
  }
}
