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

  /// Returns JPEG bytes ready to encrypt, or null when [bytes] is not a
  /// decodable image.
  static Future<Uint8List?> prepare(Uint8List bytes) =>
      compute(prepareSync, bytes);

  /// Synchronous worker — exposed for tests.
  static Uint8List? prepareSync(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return null; // Garbage bytes must never crash the editor.
    }
    if (decoded == null) return null;

    var photo = img.bakeOrientation(decoded);
    if (photo.width > maxDimension || photo.height > maxDimension) {
      photo = photo.width >= photo.height
          ? img.copyResize(photo, width: maxDimension)
          : img.copyResize(photo, height: maxDimension);
    }
    return Uint8List.fromList(img.encodeJpg(photo, quality: jpegQuality));
  }
}
