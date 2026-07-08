import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:reflect/src/features/entries/services/markdown_lite.dart';

/// Renders [MarkdownLite] output as styled text: bold, italic, and "- "
/// bullet lines. Used on the read-only entry view.
class MarkdownLiteText extends StatelessWidget {
  const MarkdownLiteText({required this.text, required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = MarkdownLite.parse(text);
    final children = <Widget>[];
    for (final line in lines) {
      if (line.spans.isEmpty && !line.bullet) {
        // Blank line: paragraph gap.
        children.add(SizedBox(height: (style.fontSize ?? 16) * 0.6));
        continue;
      }
      final rich = Text.rich(
        TextSpan(children: [for (final span in line.spans) _span(span)]),
        style: style,
      );
      children.add(
        line.bullet
            ? Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•', style: style),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: rich),
                  ],
                ),
              )
            : rich,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  TextSpan _span(MdSpan span) => TextSpan(
        text: span.text,
        style: TextStyle(
          fontWeight: span.bold ? FontWeight.w700 : null,
          fontStyle: span.italic ? FontStyle.italic : null,
        ),
      );
}
