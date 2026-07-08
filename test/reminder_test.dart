import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/core/storage_keys.dart';
import 'package:reflect/src/features/reminders/providers/reminder_providers.dart';
import 'package:reflect/src/features/reminders/services/reminder_time.dart';

import 'fakes/fakes.dart';

void main() {
  group('ReminderTime.nextDailyFire', () {
    test('later today when the time has not passed yet', () {
      final now = DateTime(2026, 7, 7, 8, 30);
      expect(
        ReminderTime.nextDailyFire(now, 21, 0),
        DateTime(2026, 7, 7, 21, 0),
      );
    });

    test('tomorrow when the time already passed', () {
      final now = DateTime(2026, 7, 7, 21, 0); // Exactly on the dot.
      expect(
        ReminderTime.nextDailyFire(now, 21, 0),
        DateTime(2026, 7, 8, 21, 0),
      );
    });

    test('rolls over month and year boundaries at midnight', () {
      expect(
        ReminderTime.nextDailyFire(DateTime(2026, 12, 31, 23, 59), 21, 0),
        DateTime(2027, 1, 1, 21, 0),
      );
      // A minute past a 00:05 reminder, just after midnight.
      expect(
        ReminderTime.nextDailyFire(DateTime(2026, 7, 8, 0, 6), 0, 5),
        DateTime(2026, 7, 9, 0, 5),
      );
      // Just before it fires.
      expect(
        ReminderTime.nextDailyFire(DateTime(2026, 7, 8, 0, 4), 0, 5),
        DateTime(2026, 7, 8, 0, 5),
      );
    });

    test(
        'uses calendar arithmetic so DST-length days still pin to the '
        'wall clock', () {
      // Feb 28 in a leap year → Feb 29, not Mar 1.
      expect(
        ReminderTime.nextDailyFire(DateTime(2028, 2, 28, 22, 0), 21, 0),
        DateTime(2028, 2, 29, 21, 0),
      );
      // Even for a 23h/25h DST day, DateTime(y, m, d+1, h, m) yields the
      // requested wall-clock time rather than "now + 24h".
      final next =
          ReminderTime.nextDailyFire(DateTime(2026, 3, 8, 22, 0), 21, 30);
      expect(next.hour, 21);
      expect(next.minute, 30);
      expect(next.day, 9);
    });
  });

  group('ReminderSettings codec', () {
    test('round-trips', () {
      const settings = ReminderSettings(enabled: true, hour: 7, minute: 45);
      expect(ReminderSettings.decode(settings.encode()), settings);
    });

    test('rejects garbage and out-of-range values', () {
      expect(ReminderSettings.decode(null), isNull);
      expect(ReminderSettings.decode('nope'), isNull);
      expect(
        ReminderSettings.decode('{"enabled":true,"hour":24,"minute":0}'),
        isNull,
      );
      expect(
        ReminderSettings.decode('{"enabled":true,"hour":9,"minute":60}'),
        isNull,
      );
    });
  });

  group('DailyReminderNotifier', () {
    late FakeSecureStorage storage;
    late FakeReminderScheduler scheduler;
    late ProviderContainer container;

    ProviderContainer makeContainer() {
      final c = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      c.listen(dailyReminderProvider, (_, __) {});
      return c;
    }

    setUp(() {
      storage = FakeSecureStorage();
      scheduler = FakeReminderScheduler();
      container = makeContainer();
    });

    tearDown(() => container.dispose());

    test('defaults to off at 21:00', () async {
      await Future<void>.delayed(Duration.zero);
      final settings = container.read(dailyReminderProvider);
      expect(settings.enabled, isFalse);
      expect(settings.hour, 21);
      expect(settings.minute, 0);
      expect(scheduler.scheduleCount, 0);
    });

    test('enabling asks permission, schedules and persists', () async {
      final ok =
          await container.read(dailyReminderProvider.notifier).setEnabled(true);
      expect(ok, isTrue);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled, (21, 0));
      expect(
        storage.store[ReflectKeys.dailyReminder],
        contains('"enabled":true'),
      );
    });

    test('denied permission leaves the reminder off', () async {
      scheduler.permissionGranted = false;
      final ok =
          await container.read(dailyReminderProvider.notifier).setEnabled(true);
      expect(ok, isFalse);
      expect(container.read(dailyReminderProvider).enabled, isFalse);
      expect(scheduler.scheduleCount, 0);
    });

    test('changing the time reschedules while enabled', () async {
      final notifier = container.read(dailyReminderProvider.notifier);
      await notifier.setEnabled(true);
      await notifier.setTime(hour: 7, minute: 15);
      expect(scheduler.scheduled, (7, 15));
      expect(scheduler.scheduleCount, 2);
    });

    test('changing the time while disabled only persists', () async {
      await container
          .read(dailyReminderProvider.notifier)
          .setTime(hour: 6, minute: 0);
      expect(scheduler.scheduleCount, 0);
      expect(
        storage.store[ReflectKeys.dailyReminder],
        contains('"hour":6'),
      );
    });

    test('disabling cancels the pending notification', () async {
      final notifier = container.read(dailyReminderProvider.notifier);
      await notifier.setEnabled(true);
      await notifier.setEnabled(false);
      expect(scheduler.cancelCount, 1);
      expect(scheduler.scheduled, isNull);
    });

    test('a stored enabled reminder is rescheduled on app start', () async {
      await container.read(dailyReminderProvider.notifier).setEnabled(true);
      container.dispose();

      // Fresh container = fresh app start reading the same storage.
      scheduler = FakeReminderScheduler();
      container = makeContainer();
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.scheduled, (21, 0));
      expect(container.read(dailyReminderProvider).enabled, isTrue);
    });
  });
}
