import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Raw TTF bytes for the fonts embedded in the year book PDF.
///
/// Kept as plain bytes (not parsed `pw.Font` objects) so the whole bundle
/// can be sent across an isolate boundary — PDF rendering runs off the UI
/// thread via `compute`.
final class PdfFontBytes {
  const PdfFontBytes({
    required this.regular,
    required this.semiBold,
    required this.bold,
    required this.emoji,
  });

  final Uint8List regular;
  final Uint8List semiBold;
  final Uint8List bold;

  /// Monochrome (glyf) emoji face, wired in as a font fallback so mood
  /// emojis and any emoji the user typed render in the PDF — Inter has no
  /// emoji glyphs.
  final Uint8List emoji;
}

/// Loads (and caches) the Inter faces bundled with `core_theme`, so the PDF
/// uses the same typeface as the app and covers far more of Unicode than
/// the built-in Latin-1 Helvetica, plus the bundled Noto emoji face used as
/// a fallback for emoji glyphs.
abstract final class PdfFontLoader {
  static PdfFontBytes? _cache;

  static const _package = 'packages/core_theme/fonts';

  /// App asset path for the emoji font (declared under `flutter: assets:`).
  static const emojiAsset = 'assets/fonts/NotoEmoji-Regular.ttf';

  static Future<PdfFontBytes> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final results = await Future.wait([
      rootBundle.load('$_package/Inter-Regular.ttf'),
      rootBundle.load('$_package/Inter-SemiBold.ttf'),
      rootBundle.load('$_package/Inter-Bold.ttf'),
      rootBundle.load(emojiAsset),
    ]);

    return _cache = PdfFontBytes(
      regular: results[0].buffer.asUint8List(),
      semiBold: results[1].buffer.asUint8List(),
      bold: results[2].buffer.asUint8List(),
      emoji: results[3].buffer.asUint8List(),
    );
  }
}
