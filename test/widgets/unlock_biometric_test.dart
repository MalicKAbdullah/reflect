import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';
import 'package:reflect/src/features/auth/screens/unlock_screen.dart';

import '../fakes/fakes.dart';

/// Drives the unlock screen's biometric behaviour with a scriptable fake
/// authenticator: the button always shows when the persisted toggle is on,
/// the prompt auto-fires exactly once on entering the locked state, a manual
/// retry works after a cancel/failure, and the PIN is always a fallback.
void main() {
  late FakeSecureStorage storage;
  late InMemoryFileStore fileStore;
  late FakeBiometricAuth biometric;
  late FixedClock clock;
  late ProviderContainer container;

  List<Override> overrides() => [
        secureStorageProvider.overrideWithValue(storage),
        fileStoreProvider.overrideWithValue(fileStore),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        clockProvider.overrideWithValue(clock),
        biometricAuthProvider.overrideWithValue(biometric),
      ];

  Future<void> pumpUnlock(WidgetTester tester) async {
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: UnlockScreen()),
      ),
    );
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
    biometric = FakeBiometricAuth();
    clock = FixedClock(DateTime(2026, 7, 9, 12));

    // Seed a vault with a PIN and biometric unlock turned on.
    final seed = ProviderContainer(overrides: overrides());
    final setup = await seed.read(pinAuthServiceProvider).setupPin('123456');
    await seed.read(biometricUnlockServiceProvider).enable(setup.key);
    seed.dispose();
    // The enable() prompt is done; observe fresh prompts from here.
    biometric.promptCount = 0;
  });

  testWidgets('the fingerprint button shows whenever biometrics are enabled',
      (tester) async {
    biometric.authenticates = false; // keep the auto-prompt from unlocking
    await pumpUnlock(tester);
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    expect(container.read(sessionProvider), AuthStatus.locked);
  });

  testWidgets('auto-prompts once on entering locked and unlocks',
      (tester) async {
    await pumpUnlock(tester);
    expect(biometric.promptCount, 1);
    expect(container.read(sessionProvider), AuthStatus.unlocked);
  });

  testWidgets('retry after a failed prompt succeeds on a manual tap',
      (tester) async {
    biometric.authenticates = false;
    await pumpUnlock(tester);
    // Auto-prompt fired once and failed; still locked, button still there.
    expect(biometric.promptCount, 1);
    expect(container.read(sessionProvider), AuthStatus.locked);

    biometric.authenticates = true;
    await tester.tap(find.byIcon(Icons.fingerprint_rounded));
    await tester.pumpAndSettle();
    expect(biometric.promptCount, 2);
    expect(container.read(sessionProvider), AuthStatus.unlocked);
  });

  testWidgets('PIN always unlocks even when biometrics fail', (tester) async {
    biometric.authenticates = false;
    await pumpUnlock(tester);
    expect(container.read(sessionProvider), AuthStatus.locked);
    await enterPin(tester, '123456');
    expect(container.read(sessionProvider), AuthStatus.unlocked);
  });

  testWidgets('hardware unavailable shows a note and does not prompt',
      (tester) async {
    biometric.available = false;
    await pumpUnlock(tester);
    expect(biometric.promptCount, 0);
    expect(find.textContaining('Biometric hardware is unavailable'),
        findsOneWidget);
    // Button is still offered (toggle is on), and the PIN still works.
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    await enterPin(tester, '123456');
    expect(container.read(sessionProvider), AuthStatus.unlocked);
  });
}
