import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';

import 'fakes/fakes.dart';

/// End-to-end provider flow with fakes: setup → CRUD → search index sync →
/// lock → unlock → data survives (encrypted at rest).
void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    storage = FakeSecureStorage();
    fileStore = InMemoryFileStore();
    clock = FixedClock(DateTime(2026, 7, 3, 12));
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        attachmentStoreProvider.overrideWithValue(FakeAttachmentStore()),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(clock),
      ],
    );
    // Keep the providers alive for the whole test.
    container.listen(sessionProvider, (_, __) {});
    container.listen(entriesProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('full session flow: add, search, update, delete, lock, unlock',
      () async {
    final session = container.read(sessionProvider.notifier);
    await session.setup('123456');
    expect(container.read(sessionProvider), AuthStatus.unlocked);

    final entries = container.read(entriesProvider.notifier);
    expect(await entries.future, isEmpty);

    // Add: persisted encrypted, indexed for search.
    final added = await entries.addEntry(
      title: 'Morning',
      body: 'Meditation before sunrise',
      mood: 5,
      tags: ['calm'],
    );
    expect(fileStore.bytes, isNotNull);
    expect(
      container.read(searchIndexProvider).search('medit').single.id,
      added.id,
    );

    // Update: index follows the new text.
    clock.advance(const Duration(minutes: 5));
    await entries.updateEntry(added.copyWith(body: 'Went swimming instead'));
    final index = container.read(searchIndexProvider);
    expect(index.search('meditation'), isEmpty);
    expect(index.search('swimming').single.id, added.id);

    // Lock: session key gone, plaintext state dropped, index cleared.
    session.lock();
    expect(container.read(sessionProvider), AuthStatus.locked);
    expect(() => session.dataKey, throwsStateError);
    expect(await container.read(entriesProvider.future), isEmpty);
    expect(container.read(searchIndexProvider).documentCount, 0);

    // Unlock: entries reload from the encrypted file, index rebuilt.
    await session.unlock('123456');
    final reloaded = await container.read(entriesProvider.future);
    expect(reloaded.single.body, 'Went swimming instead');
    expect(
      container.read(searchIndexProvider).search('swimming').length,
      1,
    );

    // Delete: removed from storage and index.
    await container.read(entriesProvider.notifier).deleteEntry(added.id);
    expect(await container.read(entriesProvider.future), isEmpty);
    expect(container.read(searchIndexProvider).search('swimming'), isEmpty);
  });

  test('erase-all wipes data and returns to setup', () async {
    final session = container.read(sessionProvider.notifier);
    await session.setup('123456');
    await container
        .read(entriesProvider.notifier)
        .addEntry(body: 'to be erased', mood: 1);

    await session.eraseAll();
    expect(container.read(sessionProvider), AuthStatus.needsSetup);
    expect(fileStore.bytes, isNull);
    expect(storage.store, isEmpty);
  });
}
