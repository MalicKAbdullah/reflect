import 'dart:typed_data';

import 'package:reflect/src/features/attachments/services/attachment_service.dart';
import 'package:reflect/src/features/attachments/services/photo_codec.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// Gathers decrypted, print-downscaled JPEG bytes for the photos in one
/// year's entries, ready to hand to the year-book render isolate.
///
/// Decryption uses the in-memory session [key] and must therefore run on the
/// main isolate, before `compute()`. Each entry contributes at most
/// [maxPerEntry] photos; unreadable photos are silently skipped.
Future<Map<String, Uint8List>> loadYearBookPhotos({
  required AttachmentService service,
  required Uint8List key,
  required List<JournalEntry> entries,
  required int year,
  required int maxPerEntry,
}) async {
  final result = <String, Uint8List>{};
  for (final entry in entries) {
    if (entry.createdAt.year != year) continue;
    for (final id in entry.photoIds.take(maxPerEntry)) {
      if (result.containsKey(id)) continue;
      final bytes = await service.loadPhoto(id: id, key: key);
      if (bytes == null) continue;
      result[id] = await PhotoCodec.prepareForPrint(bytes);
    }
  }
  return result;
}
