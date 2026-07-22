import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/app.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';

import '../fakes/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late ProviderContainer container;

  List<Override> overrides() => [
        secureStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        attachmentStoreProvider.overrideWithValue(FakeAttachmentStore()),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 7, 7))),
        biometricAuthProvider
            .overrideWithValue(FakeBiometricAuth(available: false)),
      ];

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ReflectApp(),
      ),
    );
    container.read(sessionProvider);
    await tester.pumpAndSettle();
  }

  setUp(() {
    storage = FakeSecureStorage();
    fileStore = InMemoryFileStore();
  });

  testWidgets('first run walks through onboarding into PIN setup',
      (tester) async {
    await pumpApp(tester);

    // Page 1 of the welcome flow.
    expect(find.text('Your private space to reflect'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Locked with your password'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Capture the day your way'), findsOneWidget);

    await tester.tap(find.text('Set up my password'));
    await tester.pumpAndSettle();

    // Landed on PIN setup, and the flag is recorded.
    expect(find.text('Welcome to Reflect'), findsOneWidget);
    expect(storage.store[ReflectKeys.onboardingSeen], '1');
  });

  testWidgets('skip jumps straight to PIN setup', (tester) async {
    await pumpApp(tester);
    expect(find.text('Your private space to reflect'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Reflect'), findsOneWidget);
    expect(storage.store[ReflectKeys.onboardingSeen], '1');
  });

  testWidgets('a device with a PIN goes straight to unlock — no onboarding',
      (tester) async {
    // Seed an existing vault (a "subsequent run").
    final seed = ProviderContainer(overrides: overrides());
    await seed.read(pinAuthServiceProvider).setupPin('123456');
    seed.dispose();

    await pumpApp(tester);

    expect(find.text('Your private space to reflect'), findsNothing);
    expect(find.text('Welcome to Reflect'), findsNothing);
    expect(
      find.text('Enter your password to unlock your journal'),
      findsOneWidget,
    );
  });
}
