import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';
import 'package:reflect/src/features/tags/providers/tag_providers.dart';

import 'fakes/fakes.dart';

/// Tag browsing and management on top of the live provider flow.
void main() {
  late ProviderContainer container;
  late FixedClock clock;

  setUp(() async {
    clock = FixedClock(DateTime(2026, 7, 3, 12));
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        fileStoreProvider.overrideWithValue(InMemoryFileStore()),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(clock),
      ],
    );
    container.listen(sessionProvider, (_, __) {});
    container.listen(entriesProvider, (_, __) {});
    await container.read(sessionProvider.notifier).setup('123456');
    final entries = container.read(entriesProvider.notifier);
    await entries.addEntry(
      body: 'walk in the park',
      mood: 4,
      tags: ['calm', 'outside'],
    );
    clock.advance(const Duration(minutes: 1));
    await entries.addEntry(
      body: 'busy standup day',
      mood: 2,
      tags: ['work', 'stressed'],
    );
    clock.advance(const Duration(minutes: 1));
    await entries.addEntry(
      body: 'deep work morning',
      mood: 5,
      tags: ['work', 'calm'],
    );
  });

  tearDown(() => container.dispose());

  test('tagCounts aggregates and sorts by count then name', () {
    final counts = container.read(tagCountsProvider);
    expect(
      counts.map((c) => '${c.tag}:${c.count}').toList(),
      ['calm:2', 'work:2', 'outside:1', 'stressed:1'],
    );
  });

  test('entriesByTag filters, newest first', () {
    final work = container.read(entriesByTagProvider('work'));
    expect(work.map((e) => e.body).toList(),
        ['deep work morning', 'busy standup day']);
    expect(container.read(entriesByTagProvider('nope')), isEmpty);
  });

  test('renameTag rewrites every affected entry and bumps updatedAt', () async {
    clock.advance(const Duration(hours: 1));
    final changed = await container
        .read(entriesProvider.notifier)
        .renameTag('work', 'focus');
    expect(changed, 2);

    final entries = container.read(entriesProvider).value!;
    final tagged = entries.where((e) => e.tags.contains('focus')).toList();
    expect(tagged, hasLength(2));
    expect(entries.any((e) => e.tags.contains('work')), isFalse);
    for (final e in tagged) {
      expect(e.updatedAt, clock.now());
    }
    // Search index follows the rename.
    expect(container.read(searchIndexProvider).search('focus'), hasLength(2));
    // Only the body occurrence of "work" is left in the index.
    expect(container.read(searchIndexProvider).search('work'), hasLength(1));
  });

  test('renaming onto an existing tag deduplicates', () async {
    final changed = await container
        .read(entriesProvider.notifier)
        .renameTag('work', 'calm');
    expect(changed, 2);
    final entries = container.read(entriesProvider).value!;
    for (final e in entries) {
      expect(e.tags.where((t) => t == 'calm').length, lessThanOrEqualTo(1));
    }
  });

  test('deleteTag strips the tag but keeps the entries', () async {
    final changed =
        await container.read(entriesProvider.notifier).deleteTag('calm');
    expect(changed, 2);
    final entries = container.read(entriesProvider).value!;
    expect(entries, hasLength(3));
    expect(entries.any((e) => e.tags.contains('calm')), isFalse);
    expect(container.read(tagCountsProvider).map((c) => c.tag),
        isNot(contains('calm')));
  });

  test('rename of an unknown tag touches nothing', () async {
    final changed = await container
        .read(entriesProvider.notifier)
        .renameTag('ghost', 'real');
    expect(changed, 0);
  });
}
