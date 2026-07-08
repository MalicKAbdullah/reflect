/// Schedules the daily writing reminder notification. Abstract so tests and
/// widget previews inject a fake — the notification-plugin implementation is
/// only constructed in main().
abstract interface class IReminderScheduler {
  Future<void> initialize();

  /// Asks the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Replaces any pending reminder with a daily one at [hour]:[minute]
  /// (device local time).
  Future<void> scheduleDaily({required int hour, required int minute});

  Future<void> cancel();
}

/// Default no-op implementation used outside a real device context.
final class NoopReminderScheduler implements IReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {}

  @override
  Future<void> cancel() async {}
}
