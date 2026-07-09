import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts + colors the [MarkdownPdf] renderer needs. Inter ships no italic
/// face, so emphasis borrows the semi-bold weight; code uses the built-in
/// Courier monospace with the text fonts as fallbacks.
final class MarkdownPdfTheme {
  const MarkdownPdfTheme({
    required this.regular,
    required this.semiBold,
    required this.bold,
    required this.mono,
    required this.fallback,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.line,
    required this.codeBackground,
    this.baseFontSize = 10.5,
    this.lineSpacing = 3,
    this.blockGap = 5,
  });

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;
  final pw.Font mono;

  /// Fonts consulted for glyphs the primary face lacks (notably emoji).
  final List<pw.Font> fallback;

  final PdfColor ink;
  final PdfColor muted;
  final PdfColor accent;
  final PdfColor line;
  final PdfColor codeBackground;
  final double baseFontSize;
  final double lineSpacing;

  /// Vertical space inserted between consecutive block widgets.
  final double blockGap;
}

/// Renders CommonMark (GitHub-flavored) into a FLAT list of `package:pdf`
/// widgets suitable for a [pw.MultiPage] `build` list.
///
/// Every widget returned is either short (headings, list items, rules) or a
/// [pw.RichText] with `overflow: TextOverflow.span` — so a long paragraph
/// paginates across pages instead of overflowing. Nothing is wrapped in a
/// single non-breakable container, which is what previously made tall
/// entries collide with the footer and the next entry.
///
/// It never throws on odd input — parse failures degrade to a plain
/// paragraph.
final class MarkdownPdf {
  const MarkdownPdf(this.theme);

  final MarkdownPdfTheme theme;

  static const _headingSizes = <String, double>{
    'h1': 18,
    'h2': 15,
    'h3': 13,
    'h4': 12,
    'h5': 11,
    'h6': 10.5,
  };

  /// A flat list of block widgets with [MarkdownPdfTheme.blockGap] spacing
  /// interleaved between them. Safe to spread directly into a MultiPage.
  List<pw.Widget> build(String source) {
    if (source.trim().isEmpty) return const [];
    List<md.Node> nodes;
    try {
      nodes = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parseLines(const LineSplitter().convert(source));
    } catch (_) {
      // Robustness: never let malformed markdown crash a year book.
      return [_paragraph(source)];
    }
    final blocks = <pw.Widget>[];
    for (final node in nodes) {
      _appendBlock(node, blocks);
    }
    // Interleave consistent spacing so nothing ever overlaps.
    final out = <pw.Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) out.add(pw.SizedBox(height: theme.blockGap));
      out.add(blocks[i]);
    }
    return out;
  }

  // ── Block nodes ────────────────────────────────────────────────────────

  void _appendBlock(md.Node node, List<pw.Widget> out) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) out.add(_paragraph(text));
      return;
    }
    if (node is! md.Element) return;

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        out.add(_heading(node));
      case 'p':
        out.add(_richBlock(_inline(node.children, _base())));
      case 'ul':
        out.add(_list(node, ordered: false));
      case 'ol':
        out.add(_list(node, ordered: true));
      case 'blockquote':
        out.add(_blockquote(node));
      case 'pre':
        out.add(_codeBlock(node));
      case 'hr':
        out.add(_rule());
      default:
        // Tables and any unknown block: render children, else its text.
        if (node.children != null && node.children!.isNotEmpty) {
          for (final child in node.children!) {
            _appendBlock(child, out);
          }
        } else {
          final text = node.textContent.trim();
          if (text.isNotEmpty) out.add(_paragraph(text));
        }
    }
  }

  pw.Widget _heading(md.Element node) {
    final size = _headingSizes[node.tag] ?? theme.baseFontSize;
    return pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        children: _inline(
          node.children,
          pw.TextStyle(
            font: theme.bold,
            fontFallback: theme.fallback,
            fontSize: size,
            color: theme.ink,
            lineSpacing: theme.lineSpacing,
          ),
        ),
      ),
    );
  }

  /// A whole markdown list as ONE vertical column. A vertical column is a
  /// spanning widget, so a long list paginates between its items rather than
  /// overflowing.
  pw.Widget _list(md.Element node, {required bool ordered}) {
    final items = <pw.Widget>[];
    var index = 1;
    for (final child in node.children ?? const <md.Node>[]) {
      if (child is! md.Element) continue;
      items.add(_listItem(child, ordered ? '$index.' : '•'));
      index++;
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items,
    );
  }

  pw.Widget _listItem(md.Element item, String marker) {
    // A list item holds inline content and possibly nested blocks.
    final inlineChildren = <md.Node>[];
    final blockChildren = <md.Node>[];
    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element &&
          (child.tag == 'ul' ||
              child.tag == 'ol' ||
              child.tag == 'p' ||
              child.tag == 'pre' ||
              child.tag == 'blockquote')) {
        blockChildren.add(child);
      } else {
        inlineChildren.add(child);
      }
    }
    final nested = <pw.Widget>[];
    for (final block in blockChildren) {
      _appendBlock(block, nested);
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 16,
            child: pw.Text(
              marker,
              style: pw.TextStyle(
                font: theme.regular,
                fontFallback: theme.fallback,
                fontSize: theme.baseFontSize,
                color: theme.accent,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (inlineChildren.isNotEmpty)
                  pw.RichText(
                    overflow: pw.TextOverflow.span,
                    text: pw.TextSpan(children: _inline(inlineChildren, _base())),
                  ),
                for (final widget in nested) ...[
                  if (widget != nested.first) pw.SizedBox(height: theme.blockGap),
                  widget,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _blockquote(md.Element node) {
    final inner = <pw.Widget>[];
    for (final child in node.children ?? const <md.Node>[]) {
      _appendBlock(child, inner);
    }
    final children = <pw.Widget>[];
    for (var i = 0; i < inner.length; i++) {
      if (i > 0) children.add(pw.SizedBox(height: theme.blockGap));
      children.add(inner[i]);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 10, top: 2, bottom: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: theme.accent, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children.isEmpty ? [_paragraph(node.textContent.trim())] : children,
      ),
    );
  }

  pw.Widget _codeBlock(md.Element node) {
    final code = node.textContent.replaceAll(RegExp(r'\n$'), '');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: theme.codeBackground,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.RichText(
        overflow: pw.TextOverflow.span,
        text: pw.TextSpan(
          text: code,
          style: pw.TextStyle(
            font: theme.mono,
            fontFallback: [theme.regular, ...theme.fallback],
            fontSize: theme.baseFontSize - 1,
            color: theme.ink,
            lineSpacing: theme.lineSpacing,
          ),
        ),
      ),
    );
  }

  pw.Widget _rule() => pw.Container(height: 1, color: theme.line);

  pw.Widget _paragraph(String text) =>
      _richBlock([pw.TextSpan(text: text, style: _base())]);

  pw.Widget _richBlock(List<pw.InlineSpan> spans) => pw.RichText(
        overflow: pw.TextOverflow.span,
        text: pw.TextSpan(children: spans),
      );

  // ── Inline nodes ─────────────────────────────────────────────────────

  pw.TextStyle _base() => pw.TextStyle(
        font: theme.regular,
        fontFallback: theme.fallback,
        fontSize: theme.baseFontSize,
        color: theme.ink,
        lineSpacing: theme.lineSpacing,
      );

  List<pw.InlineSpan> _inline(List<md.Node>? nodes, pw.TextStyle style) {
    final spans = <pw.InlineSpan>[];
    for (final node in nodes ?? const <md.Node>[]) {
      if (node is md.Text) {
        spans.add(pw.TextSpan(text: _unescape(node.text), style: style));
      } else if (node is md.Element) {
        spans.addAll(_inlineElement(node, style));
      }
    }
    return spans;
  }

  List<pw.InlineSpan> _inlineElement(md.Element node, pw.TextStyle style) {
    switch (node.tag) {
      case 'strong':
        return _inline(node.children, style.copyWith(font: theme.bold));
      case 'em':
        // No italic face — semi-bold reads as distinct emphasis.
        return _inline(node.children, style.copyWith(font: theme.semiBold));
      case 'del':
        return _inline(
          node.children,
          style.copyWith(decoration: pw.TextDecoration.lineThrough),
        );
      case 'code':
        return [
          pw.TextSpan(
            text: node.textContent,
            style: style.copyWith(
              font: theme.mono,
              fontFallback: [theme.regular, ...theme.fallback],
              color: theme.accent,
            ),
          ),
        ];
      case 'a':
        return _inline(
          node.children,
          style.copyWith(
            color: theme.accent,
            decoration: pw.TextDecoration.underline,
          ),
        );
      case 'br':
        return [pw.TextSpan(text: '\n', style: style)];
      case 'input':
        // GitHub task-list checkbox.
        final checked = node.attributes['checked'] != null;
        return [
          pw.TextSpan(text: checked ? '[x] ' : '[ ] ', style: style),
        ];
      default:
        return _inline(node.children, style);
    }
  }

  static String _unescape(String text) =>
      const HtmlUnescape().convert(text);
}

/// Minimal HTML entity unescape for the few entities the markdown parser can
/// emit (it is configured with `encodeHtml: false`, so this is belt-and-
/// suspenders for the handful that still slip through).
final class HtmlUnescape {
  const HtmlUnescape();

  static const _entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };

  String convert(String input) {
    if (!input.contains('&')) return input;
    var out = input;
    _entities.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
