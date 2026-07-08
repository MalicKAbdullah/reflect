import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Prepares a picked photo for encrypted storage: decode, honour the EXIF
/// orientation, downscale to at most [maxDimension] on the longest side and
/// re-encode as JPEG at [jpegQuality].
///
/// Pure Dart (package:image). The heavy decode/resize runs in an isolate
/// via [prepare] so picking a 12-megapixel photo never janks the UI.
abstract final class PhotoCodec {
  static const int maxDimension = 1600;
  static const int jpegQuality = 80;

  /// Longest-edge target for photos embedded in the year book PDF; smaller
  /// than storage size to keep the document and peak memory reasonable.
  static const int printDimension = 1000;
  static const int printQuality = 75;

  /// Returns JPEG bytes ready to encrypt, or null when [bytes] is not a
  /// decodable image.
  static Future<Uint8List?> prepare(Uint8List bytes) =>
      compute(prepareSync, bytes);

  /// Downscales an already-decoded JPEG for print in a background isolate.
  /// Returns the original bytes unchanged if it cannot be re-encoded.
  static Future<Uint8List> prepareForPrint(Uint8List bytes) =>
      compute(prepareForPrintSync, bytes);

  /// Synchronous worker — exposed for tests.
  static Uint8List? prepareSync(
    Uint8List bytes, {
    int longEdge = maxDimension,
    int quality = jpegQuality,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null; // Garbage bytes must never crash the editor.
    }
    if (decoded == null) return null;

    var photo = img.bakeOrientation(decoded);
    if (photo.width > longEdge || photo.height > longEdge) {
      photo = photo.width >= photo.height
          ? img.copyResize(photo, width: longEdge)
          : img.copyResize(photo, height: longEdge);
    }
    return Uint8List.fromList(img.encodeJpg(photo, quality: quality));
  }

  /// Print-downscale worker — exposed for tests. Never returns null: on any
  /// failure the caller keeps the original bytes.
  static Uint8List prepareForPrintSync(Uint8List bytes) {
    final out = prepareSync(
      bytes,
      longEdge: printDimension,
      quality: printQuality,
    );
    return out ?? bytes;
  }
}
