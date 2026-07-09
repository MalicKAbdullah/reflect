import 'dart:convert';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Renders a journal entry body as full CommonMark (GitHub-flavored):
/// headings, bold/italic, ordered & unordered lists, task lists,
/// blockquotes, inline and fenced code, links, and horizontal rules.
///
/// `flutter_markdown` is discontinued and rendered unreliably, so this
/// renders the shared `markdown` package AST directly into Flutter widgets —
/// the same parser the PDF exporter uses, so the reader and the year book
/// agree. Reading-comfortable typography derived from the app theme; links
/// are tappable via url_launcher and a link that cannot open fails quietly.
class MarkdownEntryBody extends StatefulWidget {
  const MarkdownEntryBody({required this.data, required this.baseStyle, super.key});

  final String data;
  final TextStyle baseStyle;

  @override
  State<MarkdownEntryBody> createState() => _MarkdownEntryBodyState();
}

class _MarkdownEntryBodyState extends State<MarkdownEntryBody> {
  /// Link tap recognizers, owned here so they can be disposed. Rebuilt each
  /// build (the parse is cheap) — old ones are torn down first.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final blocks = _MarkdownBuilder(
      Theme.of(context).colorScheme,
      widget.baseStyle,
      _recognizers,
    ).build(widget.data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

/// Turns a markdown source string into a flat list of block widgets. Never
/// throws on odd input — a parse failure degrades to a plain paragraph.
class _MarkdownBuilder {
  _MarkdownBuilder(this.scheme, this.baseStyle, this.recognizers);

  final ColorScheme scheme;
  final TextStyle baseStyle;
  final List<TapGestureRecognizer> recognizers;

  double get _size => baseStyle.fontSize ?? 16;
  double get _gap => _size * 0.55;

  static const Map<int, double> _headingScale = {
    1: 1.7,
    2: 1.4,
    3: 1.2,
    4: 1.1,
    5: 1.0,
    6: 0.9,
  };

  List<Widget> build(String source) {
    if (source.trim().isEmpty) return const [];
    List<md.Node> nodes;
    try {
      nodes = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parseLines(const LineSplitter().convert(source));
    } catch (_) {
      return [Text(source, style: baseStyle)];
    }
    final widgets = <Widget>[];
    for (final node in nodes) {
      _appendBlock(node, widgets);
    }
    return widgets;
  }

  // ── Block nodes ────────────────────────────────────────────────────────

  void _appendBlock(md.Node node, List<Widget> out) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) out.add(_spaced(_paragraph([TextSpan(text: text)])));
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
        out.add(_spaced(_heading(node)));
      case 'p':
        out.add(_spaced(_paragraph(_inline(node.children, baseStyle))));
      case 'ul':
        out.add(_spaced(_list(node, ordered: false)));
      case 'ol':
        out.add(_spaced(_list(node, ordered: true)));
      case 'blockquote':
        out.add(_spaced(_blockquote(node)));
      case 'pre':
        out.add(_spaced(_codeBlock(node)));
      case 'hr':
        out.add(_spaced(_rule()));
      default:
        // Tables and any unknown block: render children, else its text.
        if (node.children != null && node.children!.isNotEmpty) {
          for (final child in node.children!) {
            _appendBlock(child, out);
          }
        } else {
          final text = node.textContent.trim();
          if (text.isNotEmpty) {
            out.add(_spaced(_paragraph([TextSpan(text: text)])));
          }
        }
    }
  }

  Widget _spaced(Widget child) => Padding(
        padding: EdgeInsets.only(bottom: _gap),
        child: child,
      );

  Widget _paragraph(List<InlineSpan> spans) => Text.rich(
        TextSpan(style: baseStyle, children: spans),
        textAlign: TextAlign.left,
      );

  Widget _heading(md.Element node) {
    final level = int.tryParse(node.tag.substring(1)) ?? 6;
    final style = baseStyle.copyWith(
      fontSize: _size * (_headingScale[level] ?? 1.0),
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
      height: 1.3,
    );
    return Text.rich(
      TextSpan(style: style, children: _inline(node.children, style)),
      textAlign: TextAlign.left,
    );
  }

  Widget _list(md.Element node, {required bool ordered}) {
    final items = <Widget>[];
    var index = 1;
    for (final child in node.children ?? const <md.Node>[]) {
      if (child is! md.Element) continue;
      items.add(_listItem(child, ordered ? '$index.' : '•'));
      index++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _listItem(md.Element item, String fallbackMarker) {
    final inlineChildren = <md.Node>[];
    final blockChildren = <md.Node>[];
    bool? taskChecked;

    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'input') {
        taskChecked = child.attributes['checked'] != null;
        continue;
      }
      if (child is md.Element &&
          const {'ul', 'ol', 'p', 'pre', 'blockquote'}.contains(child.tag)) {
        blockChildren.add(child);
      } else {
        inlineChildren.add(child);
      }
    }

    final nested = <Widget>[];
    for (final block in blockChildren) {
      _appendBlock(block, nested);
    }

    final Widget marker = taskChecked == null
        ? Text(
            fallbackMarker,
            style: baseStyle.copyWith(color: scheme.primary),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              taskChecked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: _size,
              color: taskChecked ? scheme.primary : scheme.onSurfaceVariant,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: _gap * 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _size * 1.4, child: marker),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inlineChildren.isNotEmpty)
                  _paragraph(_inline(inlineChildren, baseStyle)),
                ...nested,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockquote(md.Element node) {
    final inner = <Widget>[];
    for (final child in node.children ?? const <md.Node>[]) {
      _appendBlock(child, inner);
    }
    if (inner.isEmpty) {
      inner.add(_paragraph([TextSpan(text: node.textContent.trim())]));
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: DefaultTextStyle.merge(
        style: baseStyle.copyWith(color: scheme.onSurfaceVariant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: inner,
        ),
      ),
    );
  }

  Widget _codeBlock(md.Element node) {
    final code = node.textContent.replaceAll(RegExp(r'\n$'), '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      child: Text(
        code,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Menlo', 'Courier'],
          fontSize: _size - 1,
          height: 1.4,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _rule() => Divider(color: scheme.outlineVariant, height: 1);

  // ── Inline nodes ─────────────────────────────────────────────────────

  List<InlineSpan> _inline(List<md.Node>? nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes ?? const <md.Node>[]) {
      if (node is md.Text) {
        spans.add(TextSpan(text: _unescape(node.text), style: style));
      } else if (node is md.Element) {
        spans.addAll(_inlineElement(node, style));
      }
    }
    return spans;
  }

  List<InlineSpan> _inlineElement(md.Element node, TextStyle style) {
    switch (node.tag) {
      case 'strong':
        return _inline(node.children, style.copyWith(fontWeight: FontWeight.w700));
      case 'em':
        return _inline(node.children, style.copyWith(fontStyle: FontStyle.italic));
      case 'del':
        return _inline(
          node.children,
          style.copyWith(decoration: TextDecoration.lineThrough),
        );
      case 'code':
        return [
          TextSpan(
            text: node.textContent,
            style: style.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Courier'],
              fontSize: (style.fontSize ?? _size) - 1,
              color: scheme.onSurface,
              background: Paint()
                ..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),
        ];
      case 'a':
        final href = node.attributes['href'];
        final recognizer = TapGestureRecognizer()..onTap = () => _open(href);
        recognizers.add(recognizer);
        final linkStyle = style.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
        );
        return _inline(node.children, linkStyle)
            .map((span) => span is TextSpan
                ? TextSpan(
                    text: span.text,
                    style: span.style,
                    children: span.children,
                    recognizer: recognizer,
                  )
                : span)
            .toList();
      case 'br':
        return [TextSpan(text: '\n', style: style)];
      case 'input':
        // A stray task-list checkbox outside a list item — skip it.
        return const [];
      default:
        return _inline(node.children, style);
    }
  }

  Future<void> _open(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Opening the link failed — fail quietly, never crash the reader.
    }
  }

  static String _unescape(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
