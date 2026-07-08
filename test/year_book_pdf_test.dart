import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/yearbook/services/pdf_fonts.dart';
import 'package:reflect/src/features/yearbook/services/year_book_pdf_service.dart';

PdfFontBytes? _fontCache;

/// Loads the Inter faces from the `core_theme` font files, so PDF tests stay
/// pure Dart — no asset bundle, no platform channels. Works whether core_theme
/// resolves via the monorepo path (local) or a git dependency (CI).
PdfFontBytes loadTestFonts() {
  final dir = _resolveFontsDir();
  return _fontCache ??= PdfFontBytes(
    regular: File('$dir/Inter-Regular.ttf').readAsBytesSync(),
    semiBold: File('$dir/Inter-SemiBold.ttf').readAsBytesSync(),
    bold: File('$dir/Inter-Bold.ttf').readAsBytesSync(),
  );
}

String _resolveFontsDir() {
  const local = '../../packages/core_theme/fonts';
  if (File('$local/Inter-Regular.ttf').existsSync()) return local;
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final gitDir = Directory('$pubCache/git');
  if (gitDir.existsSync()) {
    for (final entry in gitDir.listSync()) {
      if (entry is Directory && entry.path.contains('secure-suite-core')) {
        final fonts = '${entry.path}/core_theme/fonts';
        if (File('$fonts/Inter-Regular.ttf').existsSync()) return fonts;
      }
    }
  }
  throw StateError('Could not locate core_theme Inter fonts for PDF tests.');
}

JournalEntry entry(
  String id,
  DateTime createdAt, {
  String title = '',
  String body = 'A few reflective words about the day.',
  int mood = 4,
}) {
  return JournalEntry(
    id: id,
    title: title,
    body: body,
    mood: mood,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  void expectPdfMagic(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-
    expect(bytes.length, greaterThan(1000));
  }

  int pageCount(YearBookRequest request) =>
      YearBookPdfService.buildDocument(request)
          .document
          .pdfPageList
          .pages
          .length;

  test('renders valid PDF bytes with cover stats and markdown-lite body',
      () async {
    final bytes = await YearBookPdfService.render(
      YearBookRequest(
        year: 2025,
        entries: [
          entry(
            'a',
            DateTime(2025, 3, 9, 21),
            title: 'A spring evening',
            body: 'Walked home slowly.\n'
                '- **Bold** moment\n'
                '- *Quiet* moment\n'
                'And a closing thought.',
            mood: 5,
          ),
          entry('b', DateTime(2025, 11, 2, 8), mood: 2),
          // Outside the year — must be excluded, never crash.
          entry('c', DateTime(2024, 12, 31, 23)),
        ],
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('unicode-heavy entries render with the embedded Inter font', () async {
    final bytes = await YearBookPdfService.render(
      YearBookRequest(
        year: 2025,
        entries: [
          entry(
            'u',
            DateTime(2025, 6, 1),
            title: 'Zürich → Škofja Loka',
            body: 'Café conversations: «наизусть», ćevapčići, œuvres — '
                'naïve résumé après-midi.',
          ),
        ],
        fonts: loadTestFonts(),
      ),
    );
    expectPdfMagic(bytes);
  });

  test('a year of entries spills onto multiple pages', () {
    final many = [
      for (var i = 0; i < 80; i++)
        entry(
          'e$i',
          DateTime(2025, 1 + i % 12, 1 + i % 27, 20),
          title: 'Entry number ${i + 1}',
          body: List.filled(
            40,
            'Words that add up to a real paragraph of writing.',
          ).join(' '),
          mood: 1 + i % 5,
        ),
    ];
    final pages = pageCount(
      YearBookRequest(year: 2025, entries: many, fonts: loadTestFonts()),
    );
    expect(pages, greaterThan(3)); // Cover + several content pages.
  });

  test('an empty year renders a graceful single message page', () async {
    final request = YearBookRequest(
      year: 2023,
      entries: [entry('elsewhere', DateTime(2025, 5, 5))],
      fonts: loadTestFonts(),
    );
    expect(pageCount(request), 2); // Cover + message page.
    expectPdfMagic(await YearBookPdfService.render(request));
  });

  test('suggested file name is year-stamped', () {
    expect(
      YearBookPdfService.suggestedFileName(2025),
      'reflect-yearbook-2025.pdf',
    );
  });
}
