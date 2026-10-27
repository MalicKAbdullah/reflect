import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/auth/screens/recovery_screens.dart';
import 'package:reflect/src/features/auth/screens/setup_pin_screen.dart';
import 'package:reflect/src/features/auth/screens/unlock_screen.dart';
import 'package:reflect/src/features/calendar/screens/calendar_screen.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/screens/entry_editor_screen.dart';
import 'package:reflect/src/features/entries/screens/entry_view_screen.dart';
import 'package:reflect/src/features/goals/models/writing_goal.dart';
import 'package:reflect/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';
import 'package:reflect/src/features/search/screens/search_screen.dart';
import 'package:reflect/src/features/settings/screens/settings_screen.dart';
import 'package:reflect/src/features/stats/screens/stats_screen.dart';
import 'package:reflect/src/features/timeline/screens/timeline_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fakes.dart';

/// Design previews, rendered on request:
/// `GALLERY=<out dir> flutter test test/preview`. One 390 × 844 image per
/// screen and appearance, with the app's theme mode taken from the saved
/// appearance choice as at runtime. Pixel output differs per platform, so
/// these are for design review, not CI goldens.
final String? _out = Platform.environment['GALLERY'];

class _Entries extends EntriesNotifier {
  _Entries(this._entries);
  final List<JournalEntry> _entries;
  @override
  Future<List<JournalEntry>> build() async => _entries;
}

Future<void> _fonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load('packages/core_theme/fonts/$f'));
    }
    await loader.load();
  }

  await family(AppTextStyles.fontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'MonaSans-$w.ttf',
  ]);
  await family(AppTextStyles.displayFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'MonaSansDisplay-$w.ttf',
  ]);
  await family(AppTextStyles.monoFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold']) 'MonaSansMono-$w.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      '/Users/abdullah/development/flutter';
  // Monochrome emoji glyphs stand in for the platform emoji font.
  final emoji = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/NotoEmoji-Regular.ttf'));
  await emoji.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/'
            'MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

List<JournalEntry> _sample(DateTime now) {
  JournalEntry e(
    int daysAgo,
    int hour,
    String title,
    String body,
    int mood, {
    List<String> tags = const [],
  }) {
    final at = DateTime(now.year, now.month, now.day - daysAgo, hour);
    return JournalEntry(
      id: 'e$daysAgo$hour',
      title: title,
      body: body,
      mood: mood,
      tags: tags,
      createdAt: at,
      updatedAt: at,
    );
  }

  return [
    e(
        0,
        21,
        'Quiet evening',
        'Cooked for the first time in a week and '
            'finally finished the book on the shelf.',
        4,
        tags: ['calm', 'grateful']),
    e(
        0,
        8,
        'Morning pages',
        'Three pages before coffee. The light in the '
            'kitchen was lovely.',
        5,
        tags: ['energetic']),
    e(
        1,
        20,
        'Long day',
        'Back to back meetings, but the walk home helped '
            'reset things.',
        3,
        tags: ['tired']),
    e(2, 19, '', 'Called mum and talked for an hour about nothing.', 5),
    e(3, 22, 'Restless', 'Could not sleep, mind racing about next week.', 2,
        tags: ['anxious']),
    e(4, 9, 'Slow start', 'Rain all day. Tea, a nap and some reading.', 4),
    e(6, 18, 'Rough one', 'Nothing went right today.', 1, tags: ['stressed']),
    e(9, 10, 'Market day', 'Fresh bread and far too many tomatoes.', 5),
    e(12, 21, 'Planning', 'Sketched out the next three months.', 4),
    e(40, 12, 'A year ago today', 'Moved into the new flat.', 4),
  ];
}

/// A secure store holding a password ("123456"), optionally with
/// fingerprint unlock on and a recovery key, as on a set-up device.
Future<FakeSecureStorage> _vault({
  bool biometric = false,
  bool recoveryKey = false,
}) async {
  final storage = FakeSecureStorage();
  final seed = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      fileStoreProvider.overrideWithValue(InMemoryFileStore()),
      keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
      biometricAuthProvider.overrideWithValue(FakeBiometricAuth()),
    ],
  );
  final setup = await seed.read(pinAuthServiceProvider).setupPin('123456');
  if (biometric) {
    await seed.read(biometricUnlockServiceProvider).enable(setup.key);
  }
  if (recoveryKey) {
    await seed.read(pinAuthServiceProvider).createRecoveryKey(setup.key);
  }
  seed.dispose();
  return storage;
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  ThemeMode mode,
  Widget screen, {
  FakeSecureStorage? storage,
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  Future<void> Function()? act,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 16 * 2);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppearanceController.storageKey: mode.name,
  });
  final now = DateTime.now();
  final appearance = (await tester.runAsync(AppearanceController.load))!;
  final secure = storage ?? FakeSecureStorage();
  await secure.write(
    key: ReflectKeys.writingGoal,
    value: const WritingGoal(metric: GoalMetric.words, target: 200).encode(),
  );
  final key = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(now)),
        secureStorageProvider.overrideWithValue(secure),
        fileStoreProvider.overrideWithValue(InMemoryFileStore()),
        keyDerivationProvider.overrideWithValue(FakeKeyDerivation()),
        // Biometric prompts "fail" so lock previews stay on the lock.
        biometricAuthProvider
            .overrideWithValue(FakeBiometricAuth(authenticates: false)),
        entriesProvider.overrideWith(() => _Entries(_sample(now))),
        appearanceProvider.overrideWithValue(appearance),
        ...overrides,
      ],
      child: RepaintBoundary(
        key: key,
        child: ListenableBuilder(
          listenable: appearance,
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.light, accent: AppAccents.reflect),
            darkTheme:
                AppTheme.build(Brightness.dark, accent: AppAccents.reflect),
            themeMode: appearance.mode,
            home: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  if (act != null) await act();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out!).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
  // Disposes the screen so lock countdown tickers stop before the test ends.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  if (_out == null) return;
  setUpAll(_fonts);

  Future<void> unfocus(WidgetTester t) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> wrong(WidgetTester t, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await t.enterText(find.byType(TextField), '999999');
      await t.tap(find.text('Unlock'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
    }
    await unfocus(t);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final m = mode.name;

    testWidgets('lock biometric $m', (t) async {
      final vault = (await t.runAsync(() => _vault(biometric: true)))!;
      await _shot(t, '01-lock-biometric-$m', mode, const UnlockScreen(),
          storage: vault);
    });
    testWidgets('lock password $m', (t) async {
      final vault = (await t.runAsync(_vault))!;
      await _shot(t, '02-lock-password-$m', mode, const UnlockScreen(),
          storage: vault, act: () => unfocus(t));
    });
    testWidgets('lock error $m', (t) async {
      final vault = (await t.runAsync(_vault))!;
      await _shot(t, '03-lock-error-$m', mode, const UnlockScreen(),
          storage: vault, act: () => wrong(t));
    });
    testWidgets('lock cooldown $m', (t) async {
      final vault = (await t.runAsync(_vault))!;
      await _shot(t, '04-lock-cooldown-$m', mode, const UnlockScreen(),
          storage: vault, act: () => wrong(t, times: 5));
    });
    testWidgets('lock recovery $m', (t) async {
      final vault = (await t.runAsync(() => _vault(recoveryKey: true)))!;
      await _shot(t, '05-lock-recovery-$m', mode, const RecoverScreen(),
          storage: vault, act: () => unfocus(t));
    });

    testWidgets('timeline $m', (t) async {
      await _shot(t, '10-timeline-$m', mode, const TimelineScreen());
    });
    testWidgets('timeline empty $m', (t) async {
      await _shot(
        t,
        '11-timeline-empty-$m',
        mode,
        const TimelineScreen(),
        overrides: [entriesProvider.overrideWith(() => _Entries(const []))],
      );
    });
    testWidgets('entry $m', (t) async {
      await _shot(
        t,
        '12-entry-$m',
        mode,
        EntryViewScreen(entryId: _sample(DateTime.now()).first.id),
      );
    });
    testWidgets('editor $m', (t) async {
      await _shot(t, '13-editor-$m', mode, const EntryEditorScreen(),
          act: () => unfocus(t));
    });
    testWidgets('stats $m', (t) async {
      await _shot(t, '14-stats-$m', mode, const StatsScreen());
    });
    testWidgets('calendar $m', (t) async {
      await _shot(t, '15-calendar-$m', mode, const CalendarScreen());
    });
    testWidgets('search $m', (t) async {
      await _shot(
        t,
        '16-search-$m',
        mode,
        const SearchScreen(),
        overrides: [searchQueryProvider.overrideWith((_) => 'quiet')],
        act: () => unfocus(t),
      );
    });
    testWidgets('settings $m', (t) async {
      await _shot(t, '20-settings-$m', mode, const SettingsScreen());
    });
    testWidgets('setup $m', (t) async {
      await _shot(t, '30-setup-$m', mode, const SetupPinScreen(),
          act: () => unfocus(t));
    });
    testWidgets('onboarding $m', (t) async {
      await _shot(t, '31-onboarding-$m', mode, const OnboardingScreen());
    });
  }

  testWidgets('lock small phone light', (t) async {
    final vault = (await t.runAsync(_vault))!;
    await _shot(
      t,
      '06-lock-small-light',
      ThemeMode.light,
      const UnlockScreen(),
      storage: vault,
      size: const Size(360, 640),
      act: () => unfocus(t),
    );
  });
}
