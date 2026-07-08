import 'package:flutter/material.dart';
import 'package:reflect/src/features/search/services/search_index.dart';

/// Renders a snippet of [text] around the first query match, with every
/// occurrence of a query-term prefix highlighted.
class HighlightedSnippet extends StatelessWidget {
  const HighlightedSnippet({
    required this.text,
    required this.query,
    this.maxLines = 3,
    this.style,
    super.key,
  });

  final String text;
  final String query;
  final int maxLines;
  final TextStyle? style;

  static const int _contextChars = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terms = SearchIndex.tokenize(query);
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final baseStyle = style ?? theme.textTheme.bodySmall!;
    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
    );

    final ranges = _matchRanges(normalized, terms);
    final snippetStart = _snippetStart(normalized, ranges);
    final snippet = normalized.substring(snippetStart);
    final prefixEllipsis = snippetStart > 0 ? '… ' : '';

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = range.$1 - snippetStart;
      final end = range.$2 - snippetStart;
      if (end <= 0) continue;
      final safeStart = start < cursor ? cursor : start;
      if (safeStart > cursor) {
        spans.add(TextSpan(text: snippet.substring(cursor, safeStart)));
      }
      if (end > safeStart) {
        spans.add(
          TextSpan(
            text: snippet.substring(safeStart, end),
            style: highlightStyle,
          ),
        );
        cursor = end;
      }
    }
    if (cursor < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(cursor)));
    }

    return Text.rich(
      TextSpan(text: prefixEllipsis, style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Sorted (start, end) ranges where any query term matches as a
  /// word-prefix, case-insensitively.
  static List<(int, int)> _matchRanges(String text, List<String> terms) {
    if (terms.isEmpty) return const [];
    final lower = text.toLowerCase();
    final ranges = <(int, int)>[];
    final wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
    for (final match in wordPattern.allMatches(lower)) {
      final word = match.group(0)!;
      for (final term in terms) {
        if (word.startsWith(term)) {
          ranges.add((match.start, match.start + term.length));
          break;
        }
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    return ranges;
  }

  static int _snippetStart(String text, List<(int, int)> ranges) {
    if (ranges.isEmpty) return 0;
    final first = ranges.first.$1;
    if (first <= _contextChars) return 0;
    // Cut on a space so the snippet starts at a word boundary.
    final from = first - _contextChars;
    final space = text.indexOf(' ', from);
    return space == -1 || space >= first ? from : space + 1;
  }
}
