import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/yearbook/services/markdown_pdf.dart';
import 'package:reflect/src/features/yearbook/services/pdf_fonts.dart';
import 'package:reflect/src/features/yearbook/services/year_book_pdf_service.dart';

PdfFontBytes? _fontCache;

/// Loads the Inter faces from the `core_theme` font files and the bundled
/// Noto emoji font, so PDF tests stay pure Dart — no asset bundle, no
/// platform channels. Inter resolves via the monorepo path (local) or a git
/// dependency (CI); the emoji font lives in this app's assets directory.
PdfFontBytes loadTestFonts() {
  final dir = _resolveFontsDir();
  return _fontCache ??= PdfFontBytes(
    regular: File('$dir/Inter-Regular.ttf').readAsBytesSync(),
    semiBold: File('$dir/Inter-SemiBold.ttf').readAsBytesSync(),
    bold: File('$dir/Inter-Bold.ttf').readAsBytesSync(),
    emoji: File('assets/fonts/NotoEmoji-Regular.ttf').readAsBytesSync(),
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

/// A tiny but valid JPEG, standing in for decrypted photo bytes.
Uint8List tinyJpeg({int width = 16, int height = 12}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 90, 200));
  return Uint8List.fromList(img.encodeJpg(image));
}

JournalEntry entry(
  String id,
  DateTime createdAt, {
  String title = '',
  String body = 'A few reflective words about the day.',
  int mood = 4,
  List<String> photoIds = const [],
}) {
  return JournalEntry(
    id: id,
    title: title,
    body: body,
    mood: mood,
    photoIds: photoIds,
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

  test('renders valid PDF bytes with cover stats and markdown body',
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

  test('emoji font loads and a PDF builds with emoji in the content',
      () async {
    final fonts = loadTestFonts();
    expect(fonts.emoji, isNotEmpty);
    final bytes = await YearBookPdfService.render(
      YearBookRequest(
        year: 2025,
        entries: [
          entry(
            'e',
            DateTime(2025, 4, 4),
            title: 'Feeling 😄 today',
            body: 'Sunshine and coffee 🌞☕ — a genuinely good morning.',
            mood: 5,
          ),
        ],
        fonts: fonts,
      ),
    );
    expectPdfMagic(bytes);
  });

  test('photo-bearing entries embed images (bigger than the same book '
      'without photos)', () async {
    final withPhotos = YearBookRequest(
      year: 2025,
      entries: [
        entry(
          'p',
          DateTime(2025, 5, 12),
          title: 'A day in pictures',
          body: 'Two snapshots.',
          photoIds: ['ph1', 'ph2'],
        ),
      ],
      fonts: loadTestFonts(),
      photos: {'ph1': tinyJpeg(), 'ph2': tinyJpeg(width: 20, height: 20)},
    );
    final withoutPhotos = YearBookRequest(
      year: withPhotos.year,
      entries: withPhotos.entries,
      fonts: withPhotos.fonts,
      photos: withPhotos.photos,
      includePhotos: false,
    );

    final withBytes = await YearBookPdfService.render(withPhotos);
    final withoutBytes = await YearBookPdfService.render(withoutPhotos);
    expectPdfMagic(withBytes);
    expectPdfMagic(withoutBytes);
    expect(withBytes.length, greaterThan(withoutBytes.length),
        reason: 'embedding photos should add bytes to the document');
  });

  test('markdown body renders to multiple PDF nodes and valid bytes',
      () async {
    final fonts = loadTestFonts();
    final markdown = MarkdownPdf(
      MarkdownPdfTheme(
        regular: pw.Font.ttf(fonts.regular.buffer.asByteData()),
        semiBold: pw.Font.ttf(fonts.semiBold.buffer.asByteData()),
        bold: pw.Font.ttf(fonts.bold.buffer.asByteData()),
        mono: pw.Font.courier(),
        fallback: [pw.Font.ttf(fonts.emoji.buffer.asByteData())],
        ink: const PdfColor.fromInt(0xFF000000),
        muted: const PdfColor.fromInt(0xFF666666),
        accent: const PdfColor.fromInt(0xFF7C3AED),
        line: const PdfColor.fromInt(0xFFCCCCCC),
        codeBackground: const PdfColor.fromInt(0xFFF0F0F0),
      ),
    );
    const body = '# Heading\n\n'
        'A **bold** and *slanted* paragraph with `inline code` and a '
        '[link](https://example.com).\n\n'
        '- one\n- two\n\n'
        '1. first\n2. second\n\n'
        '> a quote\n\n'
        '```\ncode block\n```\n\n'
        '---\n';
    final nodes = markdown.build(body);
    expect(nodes.length, greaterThan(1));

    // And the whole thing still renders as valid PDF bytes end to end.
    final bytes = await YearBookPdfService.render(
      YearBookRequest(
        year: 2025,
        entries: [entry('m', DateTime(2025, 2, 2), body: body)],
        fonts: fonts,
      ),
    );
    expectPdfMagic(bytes);
  });

  test('malformed markdown never throws', () {
    final fonts = loadTestFonts();
    final markdown = MarkdownPdf(
      MarkdownPdfTheme(
        regular: pw.Font.ttf(fonts.regular.buffer.asByteData()),
        semiBold: pw.Font.ttf(fonts.semiBold.buffer.asByteData()),
        bold: pw.Font.ttf(fonts.bold.buffer.asByteData()),
        mono: pw.Font.courier(),
        fallback: [pw.Font.ttf(fonts.emoji.buffer.asByteData())],
        ink: const PdfColor.fromInt(0xFF000000),
        muted: const PdfColor.fromInt(0xFF666666),
        accent: const PdfColor.fromInt(0xFF7C3AED),
        line: const PdfColor.fromInt(0xFFCCCCCC),
        codeBackground: const PdfColor.fromInt(0xFFF0F0F0),
      ),
    );
    expect(() => markdown.build('**unclosed [x]( ## \n> \n- \n```'),
        returnsNormally);
    expect(markdown.build(''), isEmpty);
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

  test('a single very long entry spans pages instead of overflowing', () {
    // A body taller than one page must paginate cleanly (no throw). Before
    // the fix the whole entry was one non-breakable block and overflowed.
    final longBody = List.filled(
      120,
      'This is a long reflective sentence that keeps going and going. ',
    ).join();
    final pages = pageCount(
      YearBookRequest(
        year: 2025,
        entries: [
          entry('long', DateTime(2025, 3, 3),
              title: 'A very full day', body: longBody),
        ],
        fonts: loadTestFonts(),
      ),
    );
    expect(pages, greaterThan(2),
        reason: 'a long body should flow across multiple content pages');
  });

  test('renders a rich multi-entry sample book to build/yearbook_sample.pdf',
      () async {
    // Long paragraph reused to push entries past a single page and force
    // pagination through the middle of a body.
    final longParagraph = List.filled(
      36,
      'The afternoon light moved slowly across the desk as I wrote. ',
    ).join();

    const richBody = '# The morning ☀️\n\n'
        'A **bold** claim, an *italic* aside, some ~~struck~~ text, and a '
        'bit of `inline code` too. Visit [the docs](https://example.com).\n\n'
        '## A list of things\n\n'
        '- first thing\n'
        '- second thing with **emphasis**\n'
        '- third thing\n\n'
        '1. step one\n'
        '2. step two\n\n'
        '### Tasks\n\n'
        '- [x] shipped the fix\n'
        '- [ ] write it up\n\n'
        '> A quote worth keeping, indented and calm.\n\n'
        '```\nfinal x = compute(render, request);\nawait x;\n```\n\n'
        '---\n\n'
        'And a closing thought with an emoji 🎉.';

    final entries = <JournalEntry>[
      entry('s1', DateTime(2025, 1, 4, 9),
          title: 'New year 🎊', body: '$richBody\n\n$longParagraph', mood: 5),
      entry('s2', DateTime(2025, 1, 18, 20), body: longParagraph, mood: 3),
      entry('s3', DateTime(2025, 2, 2, 7),
          title: 'A day in pictures 📸',
          body: 'Two snapshots and a few words.\n\n$longParagraph',
          mood: 4,
          photoIds: ['p1', 'p2']),
      entry('s4', DateTime(2025, 3, 9, 21),
          title: 'Spring evening', body: richBody, mood: 2),
      entry('s5', DateTime(2025, 3, 22, 11),
          body: '## Just markdown\n\n$richBody', mood: 4),
      entry('s6', DateTime(2025, 6, 1, 8),
          title: 'Zürich → Škofja Loka',
          body: 'Café «наизусть» ćevapčići œuvres.\n\n$longParagraph',
          mood: 5),
      entry('s7', DateTime(2025, 11, 2, 8),
          title: 'Feeling 😄', body: richBody, mood: 5, photoIds: ['p3']),
    ];

    final request = YearBookRequest(
      year: 2025,
      entries: entries,
      fonts: loadTestFonts(),
      photos: {
        'p1': tinyJpeg(width: 40, height: 30),
        'p2': tinyJpeg(width: 30, height: 40),
        'p3': tinyJpeg(width: 32, height: 32),
      },
    );

    // Building never throws => no widget overflowed a page.
    final pages = pageCount(request);
    expect(pages, greaterThan(3));

    final bytes = await YearBookPdfService.render(request);
    expectPdfMagic(bytes);

    final out = File('build/yearbook_sample.pdf');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
    expect(out.existsSync(), isTrue);
    // ignore: avoid_print
    print('Wrote ${out.absolute.path} ($pages pages, ${bytes.length} bytes)');
  });
}
