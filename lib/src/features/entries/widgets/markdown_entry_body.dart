import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Renders a journal entry body as full CommonMark (GitHub-flavored):
/// headings, bold/italic, ordered & unordered lists, task lists,
/// blockquotes, inline and fenced code, links, and horizontal rules.
///
/// Reading-comfortable typography derived from the app theme. Links are
/// tappable via url_launcher; a link that cannot open fails quietly.
class MarkdownEntryBody extends StatelessWidget {
  const MarkdownEntryBody({required this.data, required this.baseStyle, super.key});

  final String data;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final codeStyle = baseStyle.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier'],
      fontSize: (baseStyle.fontSize ?? 16) - 1,
      color: scheme.onSurface,
    );

    return MarkdownBody(
      data: data,
      onTapLink: (text, href, title) => _openLink(href),
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        h1: AppTextStyles.h1.copyWith(color: scheme.onSurface),
        h2: AppTextStyles.h2.copyWith(color: scheme.onSurface),
        h3: AppTextStyles.h3.copyWith(color: scheme.onSurface),
        h4: baseStyle.copyWith(fontWeight: FontWeight.w700),
        h5: baseStyle.copyWith(fontWeight: FontWeight.w700),
        h6: baseStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
        strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        a: baseStyle.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
        ),
        listBullet: baseStyle,
        blockquote: baseStyle.copyWith(color: scheme.onSurfaceVariant),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          border: Border(
            left: BorderSide(color: scheme.primary, width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(AppSpacing.sm),
        code: codeStyle,
        codeblockPadding: const EdgeInsets.all(AppSpacing.sm),
        codeblockDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(width: 1, color: scheme.outlineVariant),
          ),
        ),
        blockSpacing: (baseStyle.fontSize ?? 16) * 0.7,
      ),
    );
  }

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Opening the link failed — fail quietly, never crash the reader.
    }
  }
}
