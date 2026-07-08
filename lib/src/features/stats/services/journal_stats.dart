import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// Average mood for one local calendar day (null when no entries).
final class DailyMood {
  const DailyMood({required this.date, required this.average});

  final DateTime date;
  final double? average;
}

/// Entry count for one week (week starts Monday, local time).
final class WeekCount {
  const WeekCount({required this.weekStart, required this.count});

  final DateTime weekStart;
  final int count;
}

/// Pure-Dart analytics over a list of journal entries.
///
/// All date math uses local calendar dates (`DateTime(y, m, d)`), which is
/// safe across DST transitions and timezones.
final class JournalStats {
  const JournalStats({
    required this.totalEntries,
    required this.totalWords,
    required this.avgWordsPerEntry,
    required this.currentStreak,
    required this.longestStreak,
    required this.moodDistribution,
    required this.averageMood,
    required this.moodTrend,
    required this.entriesPerWeek,
  });

  final int totalEntries;
  final int totalWords;
  final double avgWordsPerEntry;

  /// Consecutive days written, ending today or yesterday.
  final int currentStreak;
  final int longestStreak;

  /// mood (1–5) -> entry count.
  final Map<int, int> moodDistribution;
  final double? averageMood;

  /// One element per day, oldest first, covering [trendDays] days.
  final List<DailyMood> moodTrend;

  /// One element per week, oldest first, covering [trendWeeks] weeks.
  final List<WeekCount> entriesPerWeek;

  static const int trendDays = 30;
  static const int trendWeeks = 8;

  static int wordCount(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime _weekStart(DateTime date) =>
      _addDays(date, -(date.weekday - DateTime.monday));

  static JournalStats compute(
    List<JournalEntry> entries, {
    required DateTime now,
  }) {
    final today = _dateOnly(now);

    var totalWords = 0;
    final moodDistribution = <int, int>{};
    var moodSum = 0;
    final datesWritten = <DateTime>{};
    final moodsByDate = <DateTime, List<int>>{};

    for (final entry in entries) {
      totalWords += wordCount('${entry.title} ${entry.body}');
      moodDistribution[entry.mood] = (moodDistribution[entry.mood] ?? 0) + 1;
      moodSum += entry.mood;
      final date = entry.localDate;
      datesWritten.add(date);
      moodsByDate.putIfAbsent(date, () => []).add(entry.mood);
    }

    return JournalStats(
      totalEntries: entries.length,
      totalWords: totalWords,
      avgWordsPerEntry: entries.isEmpty ? 0 : totalWords / entries.length,
      currentStreak: _currentStreak(datesWritten, today),
      longestStreak: _longestStreak(datesWritten),
      moodDistribution: moodDistribution,
      averageMood: entries.isEmpty ? null : moodSum / entries.length,
      moodTrend: _moodTrend(moodsByDate, today),
      entriesPerWeek: _entriesPerWeek(entries, today),
    );
  }

  /// Streak ending today, or ending yesterday when today has no entry yet
  /// (writing later today extends it rather than resetting).
  static int _currentStreak(Set<DateTime> dates, DateTime today) {
    var cursor = today;
    if (!dates.contains(cursor)) {
      cursor = _addDays(cursor, -1);
      if (!dates.contains(cursor)) return 0;
    }
    var streak = 0;
    while (dates.contains(cursor)) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    return streak;
  }

  static int _longestStreak(Set<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final sorted = dates.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == _addDays(sorted[i - 1], 1)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    return longest;
  }

  static List<DailyMood> _moodTrend(
    Map<DateTime, List<int>> moodsByDate,
    DateTime today,
  ) {
    final trend = <DailyMood>[];
    for (var i = trendDays - 1; i >= 0; i--) {
      final date = _addDays(today, -i);
      final moods = moodsByDate[date];
      trend.add(
        DailyMood(
          date: date,
          average: moods == null
              ? null
              : moods.reduce((a, b) => a + b) / moods.length,
        ),
      );
    }
    return trend;
  }

  static List<WeekCount> _entriesPerWeek(
    List<JournalEntry> entries,
    DateTime today,
  ) {
    final thisWeek = _weekStart(today);
    final counts = <DateTime, int>{};
    for (final entry in entries) {
      final week = _weekStart(entry.localDate);
      counts[week] = (counts[week] ?? 0) + 1;
    }
    final weeks = <WeekCount>[];
    for (var i = trendWeeks - 1; i >= 0; i--) {
      final week = _addDays(thisWeek, -7 * i);
      weeks.add(WeekCount(weekStart: week, count: counts[week] ?? 0));
    }
    return weeks;
  }
}
