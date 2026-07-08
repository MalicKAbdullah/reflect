import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';

JournalEntry entry(
  String id,
  DateTime createdAt, {
  int mood = 3,
  String body = 'one two three',
  String title = '',
}) {
  return JournalEntry(
    id: id,
    title: title,
    body: body,
    mood: mood,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  final now = DateTime(2026, 7, 3, 15, 30); // Friday afternoon.

  group('word counts', () {
    test('empty journal', () {
      final stats = JournalStats.compute([], now: now);
      expect(stats.totalEntries, 0);
      expect(stats.totalWords, 0);
      expect(stats.avgWordsPerEntry, 0);
      expect(stats.averageMood, isNull);
    });

    test('counts words across title and body', () {
      final stats = JournalStats.compute(
        [
          entry('a', now, title: 'My day', body: 'went  well,\nreally well'),
          entry('b', now, body: 'short'),
        ],
        now: now,
      );
      // 'My day went well, really well' = 6 words, 'short' = 1.
      expect(stats.totalWords, 7);
      expect(stats.avgWordsPerEntry, closeTo(3.5, 0.001));
    });

    test('wordCount handles messy whitespace', () {
      expect(JournalStats.wordCount('  a\n\nb\t c  '), 3);
      expect(JournalStats.wordCount(''), 0);
      expect(JournalStats.wordCount('   '), 0);
    });
  });

  group('streaks', () {
    test('no entries means no streak', () {
      final stats = JournalStats.compute([], now: now);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
    });

    test('single entry today', () {
      final stats = JournalStats.compute([entry('a', now)], now: now);
      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 1);
    });

    test('streak counts consecutive days ending today', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 7, 1, 9)),
          entry('b', DateTime(2026, 7, 2, 22)),
          entry('c', DateTime(2026, 7, 3, 8)),
        ],
        now: now,
      );
      expect(stats.currentStreak, 3);
    });

    test('streak alive if last entry was yesterday', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 7, 1)),
          entry('b', DateTime(2026, 7, 2)),
        ],
        now: now,
      );
      expect(stats.currentStreak, 2);
    });

    test('streak broken by a missed day', () {
      final stats = JournalStats.compute(
        [entry('a', DateTime(2026, 6, 30))],
        now: now,
      );
      expect(stats.currentStreak, 0);
    });

    test('multiple entries in one day count once', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 7, 3, 8)),
          entry('b', DateTime(2026, 7, 3, 21)),
          entry('c', DateTime(2026, 7, 2)),
        ],
        now: now,
      );
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
    });

    test('longest streak found across gaps', () {
      final stats = JournalStats.compute(
        [
          // Run of 4 in June.
          entry('a', DateTime(2026, 6, 10)),
          entry('b', DateTime(2026, 6, 11)),
          entry('c', DateTime(2026, 6, 12)),
          entry('d', DateTime(2026, 6, 13)),
          // Gap, then run of 2 ending today.
          entry('e', DateTime(2026, 7, 2)),
          entry('f', DateTime(2026, 7, 3)),
        ],
        now: now,
      );
      expect(stats.longestStreak, 4);
      expect(stats.currentStreak, 2);
    });

    test('streak across a month boundary', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 6, 29)),
          entry('b', DateTime(2026, 6, 30)),
          entry('c', DateTime(2026, 7, 1)),
          entry('d', DateTime(2026, 7, 2)),
          entry('e', DateTime(2026, 7, 3)),
        ],
        now: now,
      );
      expect(stats.currentStreak, 5);
      expect(stats.longestStreak, 5);
    });

    test(
        'entries at different times of day still form a streak '
        '(local-date math, DST-safe)', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 7, 1, 23, 59)),
          entry('b', DateTime(2026, 7, 2, 0, 1)),
          entry('c', DateTime(2026, 7, 3, 12)),
        ],
        now: now,
      );
      expect(stats.currentStreak, 3);
    });
  });

  group('mood analytics', () {
    test('distribution counts entries per rating', () {
      final stats = JournalStats.compute(
        [
          entry('a', now, mood: 5),
          entry('b', now, mood: 5),
          entry('c', now, mood: 2),
        ],
        now: now,
      );
      expect(stats.moodDistribution, {5: 2, 2: 1});
      expect(stats.averageMood, closeTo(4.0, 0.001));
    });

    test('trend covers exactly 30 days ending today', () {
      final stats = JournalStats.compute([], now: now);
      expect(stats.moodTrend.length, JournalStats.trendDays);
      expect(stats.moodTrend.last.date, DateTime(2026, 7, 3));
      expect(stats.moodTrend.first.date, DateTime(2026, 6, 4));
    });

    test('trend averages multiple moods per day, null on empty days', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 7, 3, 9), mood: 2),
          entry('b', DateTime(2026, 7, 3, 20), mood: 5),
        ],
        now: now,
      );
      expect(stats.moodTrend.last.average, closeTo(3.5, 0.001));
      expect(stats.moodTrend[28].average, isNull);
    });

    test('entries older than the window are excluded from trend', () {
      final stats = JournalStats.compute(
        [entry('a', DateTime(2026, 1, 1), mood: 1)],
        now: now,
      );
      expect(
        stats.moodTrend.every((d) => d.average == null),
        isTrue,
      );
    });
  });

  group('entries per week', () {
    test('covers 8 weeks, aligned to Monday', () {
      final stats = JournalStats.compute([], now: now);
      expect(stats.entriesPerWeek.length, JournalStats.trendWeeks);
      // 2026-07-03 is a Friday; its week starts Monday 2026-06-29.
      expect(stats.entriesPerWeek.last.weekStart, DateTime(2026, 6, 29));
      for (final week in stats.entriesPerWeek) {
        expect(week.weekStart.weekday, DateTime.monday);
      }
    });

    test('counts entries into the right weeks', () {
      final stats = JournalStats.compute(
        [
          entry('a', DateTime(2026, 6, 29)), // this week
          entry('b', DateTime(2026, 7, 3)), // this week
          entry('c', DateTime(2026, 6, 28)), // Sunday, previous week
        ],
        now: now,
      );
      expect(stats.entriesPerWeek.last.count, 2);
      expect(stats.entriesPerWeek[6].count, 1);
    });
  });
}
