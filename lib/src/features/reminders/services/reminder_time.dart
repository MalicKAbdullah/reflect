/// Pure scheduling arithmetic for the daily reminder, kept free of plugin
/// types so it is trivially testable with the [Clock] abstraction.
abstract final class ReminderTime {
  static const int defaultHour = 21;
  static const int defaultMinute = 0;

  /// The next moment a daily reminder at [hour]:[minute] should fire,
  /// strictly after [now].
  ///
  /// Uses calendar arithmetic (`DateTime(y, m, d + 1)`) rather than
  /// `add(Duration(days: 1))`, so the reminder stays pinned to the wall
  /// clock across DST transitions (a "day" is not always 24 hours).
  static DateTime nextDailyFire(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    if (today.isAfter(now)) return today;
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// "21:00" style label used by the settings screen fallback.
  static String label(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
