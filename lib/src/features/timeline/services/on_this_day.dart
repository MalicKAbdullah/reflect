import 'package:reflect/src/features/entries/models/journal_entry.dart';

/// A memory surfaced on today's calendar date from an earlier month or year.
final class OnThisDayEntry {
  const OnThisDayEntry({required this.entry, required this.monthsAgo});

  final JournalEntry entry;

  /// Whole calendar months between the entry's month and today's month.
  final int monthsAgo;

  /// Human label like "1 year ago" or "3 months ago".
  String get label {
    if (monthsAgo >= 12) {
      final years = monthsAgo ~/ 12;
      return years == 1 ? '1 year ago' : '$years years ago';
    }
    return monthsAgo == 1 ? '1 month ago' : '$monthsAgo months ago';
  }
}

/// Selects entries written on the same day-of-month in earlier months/years.
///
/// Pure Dart. Day matching is exact, so Feb 29 memories only resurface on a
/// leap day (they are never remapped to Feb 28 or Mar 1).
abstract final class OnThisDay {
  static List<OnThisDayEntry> select(
    List<JournalEntry> entries,
    DateTime today, {
    int limit = 5,
  }) {
    final results = <OnThisDayEntry>[];
    for (final entry in entries) {
      final date = entry.localDate;
      if (date.day != today.day) continue;
      final monthsAgo =
          (today.year - date.year) * 12 + (today.month - date.month);
      if (monthsAgo <= 0) continue;
      results.add(OnThisDayEntry(entry: entry, monthsAgo: monthsAgo));
    }
    // Most recent memories first; newest entry wins within the same month.
    results.sort((a, b) {
      final byAge = a.monthsAgo.compareTo(b.monthsAgo);
      if (byAge != 0) return byAge;
      return b.entry.createdAt.compareTo(a.entry.createdAt);
    });
    return results.length > limit ? results.sublist(0, limit) : results;
  }
}
