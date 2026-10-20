import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/screens/setup_pin_screen.dart';
import 'package:reflect/src/features/auth/screens/unlock_screen.dart';
import 'package:reflect/src/features/calendar/screens/calendar_screen.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/entries/providers/entries_providers.dart';
import 'package:reflect/src/features/entries/screens/entry_editor_screen.dart';
import 'package:reflect/src/features/entries/screens/entry_view_screen.dart';
import 'package:reflect/src/features/onboarding/screens/onboarding_screen.dart';
import 'package:reflect/src/features/search/providers/search_providers.dart';
import 'package:reflect/src/features/search/screens/search_screen.dart';
import 'package:reflect/src/features/settings/screens/settings_screen.dart';
import 'package:reflect/src/features/stats/screens/stats_screen.dart';
import 'package:reflect/src/features/timeline/screens/timeline_screen.dart';

import '../fakes/fakes.dart';

/// Design previews, rendered on request:
/// `REFLECT_PREVIEW=<out dir> flutter test test/preview`. Pixel output
/// differs per platform, so these are for design review, not CI goldens.
final String? _out = Platform.environment['REFLECT_PREVIEW'];

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

Future<void> _board(
  WidgetTester tester,
  String name,
  Widget screen, {
  List<Override> overrides = const [],
  double height = 844,
}) async {
  const width = 390.0;
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize =
      const Size(width * 2 * 2 + 4, 0) + Offset(0, height * 2);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final now = DateTime.now();
  Widget pane(Brightness b) => SizedBox(
        width: width,
        height: height,
        child: ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(FixedClock(now)),
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            fileStoreProvider.overrideWithValue(InMemoryFileStore()),
            biometricAuthProvider
                .overrideWithValue(FakeBiometricAuth(available: false)),
            entriesProvider.overrideWith(() => _Entries(_sample(now))),
            ...overrides,
          ],
          child: Theme(
            data: AppTheme.build(b, accent: AppAccents.reflect),
            child: Builder(
              builder: (context) => Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => screen,
                ),
              ),
            ),
          ),
        ),
      );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, accent: AppAccents.reflect),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(width, 844),
          disableAnimations: true,
        ),
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF808080),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pane(Brightness.light),
                const SizedBox(width: 2),
                pane(Brightness.dark),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out!).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  if (_out == null) return;
  setUpAll(_fonts);

  testWidgets('timeline', (t) async {
    await _board(t, 'timeline', const TimelineScreen(), height: 1700);
  });
  testWidgets('timeline-empty', (t) async {
    await _board(
      t,
      'timeline-empty',
      const TimelineScreen(),
      overrides: [entriesProvider.overrideWith(() => _Entries(const []))],
    );
  });
  testWidgets('stats', (t) async {
    await _board(t, 'stats', const StatsScreen(), height: 1500);
  });
  testWidgets('calendar', (t) async {
    await _board(t, 'calendar', const CalendarScreen());
  });
  testWidgets('settings', (t) async {
    await _board(t, 'settings', const SettingsScreen(), height: 1700);
  });
  testWidgets('search', (t) async {
    await _board(
      t,
      'search',
      const SearchScreen(),
      overrides: [searchQueryProvider.overrideWith((_) => 'quiet')],
    );
  });
  testWidgets('editor', (t) async {
    await _board(t, 'editor', const EntryEditorScreen(), height: 1200);
  });
  testWidgets('entry', (t) async {
    final now = DateTime.now();
    await _board(
      t,
      'entry',
      EntryViewScreen(entryId: _sample(now).first.id),
    );
  });
  testWidgets('unlock', (t) async {
    await _board(t, 'unlock', const UnlockScreen());
  });
  testWidgets('setup', (t) async {
    await _board(t, 'setup', const SetupPinScreen());
  });
  testWidgets('onboarding', (t) async {
    await _board(t, 'onboarding', const OnboardingScreen());
  });
}
