import 'dart:collection';
import 'dart:typed_data';

/// Small in-memory LRU cache for decrypted photo bytes.
///
/// Bounded by total bytes so a handful of large photos cannot pile up in
/// memory. Evicted and cleared buffers are zero-filled first — plaintext
/// photo bytes must never outlive the cache entry, and [clear] is called
/// the moment the session locks.
final class PhotoLruCache {
  PhotoLruCache({this.maxBytes = 24 * 1024 * 1024});

  final int maxBytes;

  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();
  int _totalBytes = 0;

  int get length => _entries.length;

  int get totalBytes => _totalBytes;

  Uint8List? get(String id) {
    final bytes = _entries.remove(id);
    if (bytes == null) return null;
    _entries[id] = bytes; // Re-insert as most recently used.
    return bytes;
  }

  void put(String id, Uint8List bytes) {
    evict(id);
    if (bytes.length > maxBytes) return; // Never cache the uncacheable.
    _entries[id] = bytes;
    _totalBytes += bytes.length;
    while (_totalBytes > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _wipe(_entries.remove(oldest)!);
    }
  }

  void evict(String id) {
    final bytes = _entries.remove(id);
    if (bytes != null) _wipe(bytes);
  }

  /// Zeroes every cached buffer and empties the cache. Called on lock.
  void clear() {
    for (final bytes in _entries.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _entries.clear();
    _totalBytes = 0;
  }

  void _wipe(Uint8List bytes) {
    bytes.fillRange(0, bytes.length, 0);
    _totalBytes -= bytes.length;
  }
}
