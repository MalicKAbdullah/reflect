import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart'
    show sessionProvider;

/// An in-progress, unsaved entry. Kept only in memory (never written to disk
/// unencrypted) and discarded when the session locks.
@immutable
final class EntryDraft {
  const EntryDraft({
    this.title = '',
    this.body = '',
    this.mood = 3,
    this.tags = const [],
    this.photoIds = const [],
  });

  final String title;
  final String body;
  final int mood;
  final List<String> tags;
  final List<String> photoIds;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;
}

/// Drafts keyed by entry id ('new' for a fresh entry). Autosaved (debounced)
/// from the editor so navigating away never loses work mid-session.
final draftsProvider =
    NotifierProvider<DraftsNotifier, Map<String, EntryDraft>>(
  DraftsNotifier.new,
);

final class DraftsNotifier extends Notifier<Map<String, EntryDraft>> {
  static const String newEntryKey = 'new';

  @override
  Map<String, EntryDraft> build() {
    // Rebuilds on any session transition, so locking discards all draft
    // plaintext. During an unlocked session the state persists untouched.
    ref.watch(sessionProvider);
    return const {};
  }

  void save(String key, EntryDraft draft) => state = {...state, key: draft};

  void discard(String key) {
    if (!state.containsKey(key)) return;
    final next = {...state}..remove(key);
    state = next;
  }
}
