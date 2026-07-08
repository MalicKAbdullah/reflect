import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/backup/services/backup_service.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';
import 'package:uuid/uuid.dart';

final entriesProvider =
    AsyncNotifierProvider<EntriesNotifier, List<JournalEntry>>(
  EntriesNotifier.new,
);

/// Decrypted entries for the current unlocked session, newest first.
/// Rebuilds (and drops plaintext) whenever the session locks.
/// Open (non-final) so widget tests can substitute a fake notifier.
class EntriesNotifier extends AsyncNotifier<List<JournalEntry>> {
  static const _uuid = Uuid();

  @override
  Future<List<JournalEntry>> build() async {
    final status = ref.watch(sessionProvider);
    if (status != AuthStatus.unlocked) {
      ref.read(searchIndexProvider).clear();
      return const [];
    }
    final session = ref.read(sessionProvider.notifier);
    final entries = List.of(
      await ref.read(journalRepositoryProvider).load(session.dataKey),
    );
    _sort(entries);
    ref.read(searchIndexProvider).buildFrom(entries);
    return entries;
  }

  Future<JournalEntry> addEntry({
    required String body,
    required int mood,
    String title = '',
    List<String> tags = const [],
    List<String> photoIds = const [],
  }) async {
    final now = ref.read(clockProvider).now();
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: title,
      body: body,
      mood: mood,
      tags: tags,
      photoIds: photoIds,
      createdAt: now,
      updatedAt: now,
    );
    final entries = [entry, ...await future];
    await _persist(entries);
    ref.read(searchIndexProvider).addEntry(entry);
    state = AsyncData(entries);
    return entry;
  }

  Future<void> updateEntry(JournalEntry updated) async {
    final stamped = updated.copyWith(updatedAt: ref.read(clockProvider).now());
    final entries =
        (await future).map((e) => e.id == stamped.id ? stamped : e).toList();
    _sort(entries);
    await _persist(entries);
    ref.read(searchIndexProvider).updateEntry(stamped);
    state = AsyncData(entries);
  }

  /// Deletes the entry and its encrypted photo attachment files.
  Future<void> deleteEntry(String id) async {
    final current = await future;
    JournalEntry? victim;
    for (final e in current) {
      if (e.id == id) {
        victim = e;
        break;
      }
    }
    final entries = current.where((e) => e.id != id).toList();
    await _persist(entries);
    ref.read(searchIndexProvider).removeEntry(id);
    state = AsyncData(entries);
    if (victim != null && victim.photoIds.isNotEmpty) {
      await ref.read(attachmentServiceProvider).deletePhotos(victim.photoIds);
    }
  }

  /// Applies an imported backup: merge by id (newer updatedAt wins) or
  /// replace the whole journal. Restores [attachments] (plaintext photo
  /// bytes from the backup, re-encrypted under the session key), persists,
  /// rebuilds the search index and sweeps attachment files no entry
  /// references any more.
  Future<void> importEntries(
    List<JournalEntry> imported, {
    required bool merge,
    Map<String, Uint8List> attachments = const {},
  }) async {
    final session = ref.read(sessionProvider.notifier);
    final service = ref.read(attachmentServiceProvider);
    if (attachments.isNotEmpty) {
      await service.importPlaintext(
        photos: attachments,
        key: session.dataKey,
        salt: session.salt,
      );
    }
    final current = await future;
    final List<JournalEntry> entries;
    if (merge) {
      entries = BackupService.merge(current, imported);
    } else {
      entries = List.of(imported);
      _sort(entries);
    }
    await _persist(entries);
    ref.read(searchIndexProvider).buildFrom(entries);
    state = AsyncData(entries);
    await service.sweepOrphans({
      for (final entry in entries) ...entry.photoIds,
    });
  }

  /// Renames [from] to [to] on every entry carrying the tag (deduplicated).
  Future<int> renameTag(String from, String to) =>
      _rewriteTags((tags) => tags.contains(from)
          ? [
              for (final t in tags)
                if (t != from) t,
              if (!tags.contains(to)) to,
            ]
          : null);

  /// Removes [tag] from every entry carrying it.
  Future<int> deleteTag(String tag) => _rewriteTags((tags) => tags.contains(tag)
      ? [
          for (final t in tags)
            if (t != tag) t,
        ]
      : null);

  /// Rewrites tags on affected entries in one persisted pass. [transform]
  /// returns the new tag list, or null when the entry is untouched.
  Future<int> _rewriteTags(
    List<String>? Function(List<String> tags) transform,
  ) async {
    final now = ref.read(clockProvider).now();
    var changed = 0;
    final entries = (await future).map((entry) {
      final next = transform(entry.tags);
      if (next == null) return entry;
      changed++;
      return entry.copyWith(tags: next, updatedAt: now);
    }).toList();
    if (changed == 0) return 0;
    await _persist(entries);
    ref.read(searchIndexProvider).buildFrom(entries);
    state = AsyncData(entries);
    return changed;
  }

  Future<void> _persist(List<JournalEntry> entries) {
    final session = ref.read(sessionProvider.notifier);
    return ref
        .read(journalRepositoryProvider)
        .save(entries, session.dataKey, session.salt);
  }

  static void _sort(List<JournalEntry> entries) =>
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Lookup of a single entry by id (null if deleted).
final entryByIdProvider = Provider.family<JournalEntry?, String>((ref, id) {
  final entries = ref.watch(entriesProvider).valueOrNull ?? const [];
  for (final entry in entries) {
    if (entry.id == id) return entry;
  }
  return null;
});
