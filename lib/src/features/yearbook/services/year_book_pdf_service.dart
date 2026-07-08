import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/entries/services/markdown_lite.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';
import 'package:reflect/src/features/yearbook/services/pdf_fonts.dart';

/// Everything needed to render one year book. Plain data only, so it can
/// be sent to a background isolate.
@immutable
final class YearBookRequest {
  const YearBookRequest({
    required this.year,
    required this.entries,
    required this.fonts,
  });

  final int year;

  /// Every journal entry; the service filters to [year] itself.
  final List<JournalEntry> entries;
  final PdfFontBytes fonts;
}

/// "Year in Review" PDF: an A4 book with a cover (entry count, total words,
/// top moods), the year's entries in chronological order under month
/// headers — markdown-lite flattened to styled text — and page numbers.
///
/// Layout is pure Dart (package:pdf) and unit-tested without platform
/// dependencies. From the UI, always call [renderInBackground]; a year of
/// entries takes long enough to render that it must not block a frame.
abstract final class YearBookPdfService {
  // Reflect violet, matched to the app accent, plus soft neutrals.
  static const PdfColor _accent = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1C1B22);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6F6C7A);
  static const PdfColor _line = PdfColor.fromInt(0xFFE6E4EC);

  static String suggestedFileName(int year) => 'reflect-yearbook-$year.pdf';

  /// Builds the document synchronously. Exposed so tests can inspect page
  /// counts; app code should prefer [renderInBackground].
  static pw.Document buildDocument(YearBookRequest request) {
    final fonts = _Fonts(request.fonts);
    final entries = request.entries
        .where((e) => e.createdAt.year == request.year)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final doc = pw.Document(
      title: 'Reflect — Year in Review ${request.year}',
      producer: 'Reflect',
    );

    doc.addPage(_cover(request.year, entries, fonts));
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(fonts),
        footer: (context) => _footer(context, fonts),
        build: (_) => entries.isEmpty
            ? [_emptyYear(request.year, fonts)]
            : _body(entries, fonts),
      ),
    );
    return doc;
  }

  /// Renders to bytes on the current isolate.
  static Future<Uint8List> render(YearBookRequest request) =>
      buildDocument(request).save();

  /// Loads fonts (cached) and renders on a background isolate.
  static Future<Uint8List> renderInBackground({
    required int year,
    required List<JournalEntry> entries,
  }) async {
    final fonts = await PdfFontLoader.load();
    return compute(
      render,
      YearBookRequest(year: year, entries: entries, fonts: fonts),
    );
  }

  // ── Pages ────────────────────────────────────────────────────────────

  static pw.Page _cover(int year, List<JournalEntry> entries, _Fonts fonts) {
    final totalWords = entries.fold<int>(
      0,
      (sum, e) => sum + JournalStats.wordCount('${e.title} ${e.body}'),
    );
    final moodCounts = <int, int>{};
    for (final entry in entries) {
      moodCounts.update(entry.mood, (n) => n + 1, ifAbsent: () => 1);
    }
    final topMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Page(
      pageTheme: _pageTheme(fonts),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Spacer(flex: 2),
          pw.Text(
            'REFLECT · YEAR IN REVIEW',
            style: pw.TextStyle(
              font: fonts.semiBold,
              fontSize: 11,
              letterSpacing: 2,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '$year',
            style: pw.TextStyle(
              font: fonts.bold,
              fontSize: 96,
              color: _accent,
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            children: [
              _coverStat('${entries.length}',
                  entries.length == 1 ? 'entry' : 'entries', fonts),
              pw.SizedBox(width: 40),
              _coverStat(_thousands(totalWords), 'words', fonts),
            ],
          ),
          if (topMoods.isNotEmpty) ...[
            pw.SizedBox(height: 36),
            pw.Text(
              'MOST FELT',
              style: pw.TextStyle(
                font: fonts.semiBold,
                fontSize: 9,
                letterSpacing: 1.5,
                color: _muted,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                for (final mood in topMoods.take(3)) ...[
                  _moodBadge(mood.key, fonts, count: mood.value),
                  pw.SizedBox(width: 12),
                ],
              ],
            ),
          ],
          pw.Spacer(flex: 3),
          pw.Container(height: 3, width: 72, color: _accent),
          pw.SizedBox(height: 10),
          pw.Text(
            'Written for you, from your private journal.',
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 10,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _emptyYear(int year, _Fonts fonts) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 160),
      child: pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'No entries in $year',
              style: pw.TextStyle(
                font: fonts.semiBold,
                fontSize: 18,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'This year is still a blank page.',
              style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 11,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<pw.Widget> _body(List<JournalEntry> entries, _Fonts fonts) {
    final monthName = DateFormat.MMMM();
    final dayName = DateFormat('EEEE, MMMM d');
    final widgets = <pw.Widget>[];
    int? currentMonth;

    for (final entry in entries) {
      if (entry.createdAt.month != currentMonth) {
        currentMonth = entry.createdAt.month;
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 18, bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  monthName.format(entry.createdAt),
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 17,
                    color: _accent,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(child: pw.Container(height: 1, color: _line)),
              ],
            ),
          ),
        );
      }
      widgets.add(_entryBlock(entry, fonts, dayName));
    }
    return widgets;
  }

  static pw.Widget _entryBlock(
    JournalEntry entry,
    _Fonts fonts,
    DateFormat dayName,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                dayName.format(entry.createdAt),
                style: pw.TextStyle(
                  font: fonts.semiBold,
                  fontSize: 9,
                  color: _muted,
                ),
              ),
              pw.SizedBox(width: 8),
              _moodBadge(entry.mood, fonts),
            ],
          ),
          if (entry.title.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                entry.title,
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 13,
                  color: _ink,
                ),
              ),
            ),
          pw.SizedBox(height: 4),
          ..._markdownLite(entry.body, fonts),
        ],
      ),
    );
  }

  /// Flattens the app's markdown-lite (bold / italic / bullets) into
  /// styled PDF text. Inter ships no italic face, so italic runs render in
  /// the semi-bold weight — distinct from both regular and bold.
  static List<pw.Widget> _markdownLite(String body, _Fonts fonts) {
    pw.TextStyle styleFor(MdSpan span) => pw.TextStyle(
          font: span.bold
              ? fonts.bold
              : (span.italic ? fonts.semiBold : fonts.regular),
          fontSize: 10.5,
          lineSpacing: 3,
          color: _ink,
        );

    final widgets = <pw.Widget>[];
    for (final line in MarkdownLite.parse(body)) {
      final text = pw.RichText(
        text: pw.TextSpan(
          children: [
            for (final span in line.spans)
              pw.TextSpan(text: span.text, style: styleFor(span)),
          ],
        ),
      );
      if (line.bullet) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '•  ',
                  style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 10.5,
                    color: _accent,
                  ),
                ),
                pw.Expanded(child: text),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: text,
          ),
        );
      }
    }
    return widgets;
  }

  // ── Building blocks ──────────────────────────────────────────────────

  static pw.PageTheme _pageTheme(_Fonts fonts) => pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(52, 48, 52, 44),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.semiBold,
          boldItalic: fonts.bold,
        ),
      );

  static pw.Widget _footer(pw.Context context, _Fonts fonts) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Reflect',
              style: pw.TextStyle(
                font: fonts.semiBold,
                fontSize: 8,
                color: _muted,
              ),
            ),
            pw.Text(
              // The cover is page 1; keep numbering natural anyway.
              '${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 8,
                color: _muted,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _coverStat(String value, String label, _Fonts fonts) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(font: fonts.bold, fontSize: 26, color: _ink),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 10,
              color: _muted,
            ),
          ),
        ],
      );

  /// Mood as a colored dot plus its label (the embedded text font has no
  /// emoji glyphs, so the app's mood colors carry the feeling instead).
  static pw.Widget _moodBadge(int mood, _Fonts fonts, {int? count}) {
    final color = PdfColor.fromInt(Mood.color(mood).toARGB32());
    final label =
        count == null ? Mood.label(mood) : '${Mood.label(mood)} ×$count';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.14),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            label,
            style:
                pw.TextStyle(font: fonts.semiBold, fontSize: 8.5, color: _ink),
          ),
        ],
      ),
    );
  }

  static String _thousands(int n) {
    final raw = '$n';
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return out.toString();
  }
}

/// Parsed `pw.Font`s built once per render.
final class _Fonts {
  _Fonts(PdfFontBytes bytes)
      : regular = pw.Font.ttf(_data(bytes.regular)),
        semiBold = pw.Font.ttf(_data(bytes.semiBold)),
        bold = pw.Font.ttf(_data(bytes.bold));

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;

  static ByteData _data(Uint8List bytes) =>
      bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
}
