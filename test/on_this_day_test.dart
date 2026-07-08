import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/timeline/services/on_this_day.dart';

JournalEntry entry(String id, DateTime createdAt) => JournalEntry(
      id: id,
      body: 'body',
      mood: 3,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  test('selects same day-of-month from earlier months and years', () {
    final today = DateTime(2026, 7, 5);
    final memories = OnThisDay.select([
      entry('lastMonth', DateTime(2026, 6, 5, 9)),
      entry('lastYear', DateTime(2025, 7, 5, 22)),
      entry('otherDay', DateTime(2026, 6, 4)),
      entry('today', DateTime(2026, 7, 5, 8)),
    ], today);

    expect(memories.map((m) => m.entry.id), ['lastMonth', 'lastYear']);
    expect(memories[0].monthsAgo, 1);
    expect(memories[1].monthsAgo, 12);
  });

  test('entries from today or the future are never memories', () {
    final today = DateTime(2026, 7, 5);
    final memories = OnThisDay.select([
      entry('today', DateTime(2026, 7, 5)),
      entry('nextMonth', DateTime(2026, 8, 5)),
    ], today);
    expect(memories, isEmpty);
  });

  test('leap day memories only resurface on a leap day', () {
    final leapEntry = entry('leap', DateTime(2024, 2, 29));

    // Feb 28 and Mar 1 of a non-leap year: nothing.
    expect(OnThisDay.select([leapEntry], DateTime(2026, 2, 28)), isEmpty);
    expect(OnThisDay.select([leapEntry], DateTime(2026, 3, 1)), isEmpty);

    // Next leap day: the memory returns (24 months later).
    final onLeapDay = OnThisDay.select([leapEntry], DateTime(2028, 2, 29));
    expect(onLeapDay.single.entry.id, 'leap');
    expect(onLeapDay.single.monthsAgo, 48);
  });

  test('sorted by recency and capped at the limit', () {
    final today = DateTime(2026, 7, 10);
    final memories = OnThisDay.select(
      [
        for (var m = 1; m <= 8; m++) entry('m$m', DateTime(2026, 7 - m, 10)),
      ],
      today,
      limit: 5,
    );
    expect(memories, hasLength(5));
    expect(memories.first.monthsAgo, 1);
    expect(memories.last.monthsAgo, 5);
  });

  test('labels read naturally', () {
    final today = DateTime(2026, 7, 5);
    OnThisDayEntry select(DateTime date) =>
        OnThisDay.select([entry('x', date)], today).single;

    expect(select(DateTime(2026, 6, 5)).label, '1 month ago');
    expect(select(DateTime(2026, 4, 5)).label, '3 months ago');
    expect(select(DateTime(2025, 7, 5)).label, '1 year ago');
    expect(select(DateTime(2023, 7, 5)).label, '3 years ago');
  });
}
