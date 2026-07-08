import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/models/mood.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';
import 'package:reflect/src/features/yearbook/services/markdown_pdf.dart';
import 'package:reflect/src/features/yearbook/services/pdf_fonts.dart';

/// Everything needed to render one year book. Plain data only, so it can
/// be sent to a background isolate.
@immutable
final class YearBookRequest {
  const YearBookRequest({
    required this.year,
    required this.entries,
    required this.fonts,
    this.photos = const {},
    this.includePhotos = true,
  });

  final int year;

  /// Every journal entry; the service filters to [year] itself.
  final List<JournalEntry> entries;
  final PdfFontBytes fonts;

  /// Decrypted, print-ready JPEG bytes keyed by photo id. Gathered on the
  /// main isolate (photos are AES-encrypted at rest and only decryptable
  /// with the in-memory session key) and passed in for embedding here.
  final Map<String, Uint8List> photos;

  /// When false the book omits photos even if [photos] is populated.
  final bool includePhotos;
}

/// "Year in Review" PDF: an A4 book with a cover (entry count, total words,
/// top moods as emoji), the year's entries in chronological order under
/// month headers — bodies rendered as real markdown, with a small grid of
/// photos under each entry — and page numbers.
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
  static const PdfColor _codeBg = PdfColor.fromInt(0xFFF2F0F7);

  /// At most this many photos are embedded per entry, to keep the PDF and
  /// peak memory reasonable.
  static const int maxPhotosPerEntry = 4;

  static String suggestedFileName(int year) => 'reflect-yearbook-$year.pdf';

  /// Builds the document synchronously. Exposed so tests can inspect page
  /// counts; app code should prefer [renderInBackground].
  static pw.Document buildDocument(YearBookRequest request) {
    final fonts = _Fonts(request.fonts);
    final markdown = MarkdownPdf(_markdownTheme(fonts));
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
            : _body(entries, fonts, markdown, request),
      ),
    );
    return doc;
  }

  /// Renders to bytes on the current isolate.
  static Future<Uint8List> render(YearBookRequest request) =>
      buildDocument(request).save();

  /// Loads fonts (cached) and renders on a background isolate. [photos]
  /// must already be decrypted (main-isolate work — see the caller).
  static Future<Uint8List> renderInBackground({
    required int year,
    required List<JournalEntry> entries,
    Map<String, Uint8List> photos = const {},
    bool includePhotos = true,
  }) async {
    final fonts = await PdfFontLoader.load();
    return compute(
      render,
      YearBookRequest(
        year: year,
        entries: entries,
        fonts: fonts,
        photos: photos,
        includePhotos: includePhotos,
      ),
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
              fontFallback: fonts.fallback,
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
                fontFallback: fonts.fallback,
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
              fontFallback: fonts.fallback,
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

  static List<pw.Widget> _body(
    List<JournalEntry> entries,
    _Fonts fonts,
    MarkdownPdf markdown,
    YearBookRequest request,
  ) {
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
                    fontFallback: fonts.fallback,
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
      widgets.add(_entryBlock(entry, fonts, dayName, markdown, request));
    }
    return widgets;
  }

  static pw.Widget _entryBlock(
    JournalEntry entry,
    _Fonts fonts,
    DateFormat dayName,
    MarkdownPdf markdown,
    YearBookRequest request,
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
                  fontFallback: fonts.fallback,
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
                  fontFallback: fonts.fallback,
                  fontSize: 13,
                  color: _ink,
                ),
              ),
            ),
          pw.SizedBox(height: 4),
          ...markdown.build(entry.body),
          ..._photos(entry, request),
        ],
      ),
    );
  }

  /// A small row of photo thumbnails under an entry (capped, decrypted
  /// bytes passed in via the request).
  static List<pw.Widget> _photos(JournalEntry entry, YearBookRequest request) {
    if (!request.includePhotos || request.photos.isEmpty) return const [];
    final images = <pw.MemoryImage>[];
    for (final id in entry.photoIds.take(maxPhotosPerEntry)) {
      final bytes = request.photos[id];
      if (bytes != null) images.add(pw.MemoryImage(bytes));
    }
    if (images.isEmpty) return const [];
    return [
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final image in images)
            pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(image, height: 96, fit: pw.BoxFit.cover),
            ),
        ],
      ),
    ];
  }

  // ── Building blocks ──────────────────────────────────────────────────

  static MarkdownPdfTheme _markdownTheme(_Fonts fonts) => MarkdownPdfTheme(
        regular: fonts.regular,
        semiBold: fonts.semiBold,
        bold: fonts.bold,
        mono: fonts.mono,
        fallback: fonts.fallback,
        ink: _ink,
        muted: _muted,
        accent: _accent,
        line: _line,
        codeBackground: _codeBg,
      );

  static pw.PageTheme _pageTheme(_Fonts fonts) => pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(52, 48, 52, 44),
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          italic: fonts.semiBold,
          boldItalic: fonts.bold,
          fontFallback: fonts.fallback,
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

  /// Mood as its emoji on a soft tint of the mood color, with an optional
  /// count. The bundled Noto emoji fallback renders the glyph (monochrome).
  static pw.Widget _moodBadge(int mood, _Fonts fonts, {int? count}) {
    final color = PdfColor.fromInt(Mood.color(mood).toARGB32());
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.14),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            Mood.emoji(mood),
            style: pw.TextStyle(
              font: fonts.emoji,
              fontFallback: fonts.fallback,
              fontSize: 11,
              color: _ink,
            ),
          ),
          if (count != null) ...[
            pw.SizedBox(width: 5),
            pw.Text(
              '×$count',
              style: pw.TextStyle(
                font: fonts.semiBold,
                fontSize: 8.5,
                color: _ink,
              ),
            ),
          ],
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

/// Parsed `pw.Font`s built once per render. Courier (a built-in PDF font)
/// provides a monospace face for code; the emoji face is used both directly
/// (mood badges) and as a fallback for any emoji in user text.
final class _Fonts {
  _Fonts(PdfFontBytes bytes)
      : regular = pw.Font.ttf(_data(bytes.regular)),
        semiBold = pw.Font.ttf(_data(bytes.semiBold)),
        bold = pw.Font.ttf(_data(bytes.bold)),
        emoji = pw.Font.ttf(_data(bytes.emoji)),
        mono = pw.Font.courier();

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;
  final pw.Font emoji;
  final pw.Font mono;

  /// Fonts consulted for glyphs a primary face lacks — chiefly emoji.
  List<pw.Font> get fallback => [emoji];

  static ByteData _data(Uint8List bytes) =>
      bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
}
