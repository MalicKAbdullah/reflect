import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Abstraction over the encrypted photo attachment files so tests can
/// inject an in-memory fake (no platform channels needed).
///
/// Each attachment is one opaque blob of already-encrypted bytes, keyed by
/// its id. Plaintext never touches this layer.
abstract interface class IAttachmentStore {
  /// Returns the encrypted bytes for [id], or null when it does not exist.
  Future<Uint8List?> read(String id);

  Future<void> write(String id, Uint8List bytes);

  Future<void> delete(String id);

  /// Ids of every stored attachment (used for orphan cleanup and backups).
  Future<List<String>> list();

  Future<void> deleteAll();
}

/// Stores each attachment as `attachments/<id>.bin` in the app documents
/// directory.
final class DocumentsAttachmentStore implements IAttachmentStore {
  const DocumentsAttachmentStore();

  static const String _dirName = 'attachments';
  static const String _extension = '.bin';

  /// Ids are UUIDs we mint ourselves; reject anything else so a crafted
  /// backup file can never escape the attachments directory.
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String id) async {
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'invalid attachment id');
    }
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$id$_extension');
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final file = await _file(id);
    // Write to a temp file then rename for a crash-safe replace.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> list() async {
    final dir = await _dir();
    final ids = <String>[];
    await for (final item in dir.list()) {
      if (item is! File) continue;
      final name = item.uri.pathSegments.last;
      if (!name.endsWith(_extension)) continue;
      ids.add(name.substring(0, name.length - _extension.length));
    }
    return ids;
  }

  @override
  Future<void> deleteAll() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
