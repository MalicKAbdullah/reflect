import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/screens/unlock_screen.dart';

import '../fakes/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late FixedClock clock;
  late ProviderContainer container;

  Future<void> pumpUnlock(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: UnlockScreen()),
      ),
    );
    // Touch the session provider so its init (hasPin lookup) runs, then
    // let it settle.
    container.read(sessionProvider);
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    storage = FakeSecureStorage();
    fileStore = InMemoryFileStore();
    clock = FixedClock(DateTime(2026, 7, 3, 12));
    // Seed an existing vault with PIN 123456 using the same fakes.
    final seedContainer = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(clock),
      ],
    );
    await seedContainer.read(pinAuthServiceProvider).setupPin('123456');
    seedContainer.dispose();
  });

  testWidgets('renders keypad and prompt', (tester) async {
    await pumpUnlock(tester);
    expect(
      find.text('Enter your PIN to unlock your journal'),
      findsOneWidget,
    );
    for (var d = 0; d <= 9; d++) {
      expect(find.text('$d'), findsOneWidget);
    }
    expect(container.read(sessionProvider), AuthStatus.locked);
  });

  testWidgets('wrong PIN shows error and stays locked', (tester) async {
    await pumpUnlock(tester);
    await enterPin(tester, '999999');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(container.read(sessionProvider), AuthStatus.locked);
  });

  testWidgets('correct PIN unlocks the session', (tester) async {
    await pumpUnlock(tester);
    await enterPin(tester, '123456');
    expect(container.read(sessionProvider), AuthStatus.unlocked);
    expect(find.textContaining('Wrong PIN'), findsNothing);
  });

  testWidgets('five wrong attempts show the cooldown message', (tester) async {
    await pumpUnlock(tester);
    for (var i = 0; i < 5; i++) {
      await enterPin(tester, '111111');
    }
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    // Correct PIN is rejected during cooldown.
    await enterPin(tester, '123456');
    expect(container.read(sessionProvider), AuthStatus.locked);
    // Cancel the countdown ticker before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
