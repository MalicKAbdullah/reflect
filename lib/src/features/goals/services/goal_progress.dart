import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/goals/models/writing_goal.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';

/// Progress against a [WritingGoal], computed with pure local-date math.
final class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.todayValue,
    required this.streak,
    required this.daysMet,
    required this.windowDays,
  });

  final WritingGoal goal;

  /// Entries or words written today, depending on the goal metric.
  final int todayValue;

  /// Consecutive days the goal was met, ending today (or yesterday when
  /// today is still in progress — writing later today extends it).
  final int streak;

  /// Days the goal was met within the trailing [windowDays] window.
  final int daysMet;
  final int windowDays;

  bool get metToday => todayValue >= goal.target;

  /// 0..1 progress toward today's target.
  double get fraction => (todayValue / goal.target).clamp(0.0, 1.0).toDouble();

  static const int defaultWindowDays = 30;

  static GoalProgress compute(
    List<JournalEntry> entries,
    WritingGoal goal, {
    required DateTime now,
    int windowDays = defaultWindowDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final valueByDay = <DateTime, int>{};
    for (final entry in entries) {
      final weight = goal.metric == GoalMetric.entries
          ? 1
          : JournalStats.wordCount('${entry.title} ${entry.body}');
      valueByDay.update(
        entry.localDate,
        (v) => v + weight,
        ifAbsent: () => weight,
      );
    }

    bool met(DateTime day) => (valueByDay[day] ?? 0) >= goal.target;
    DateTime addDays(DateTime d, int days) =>
        DateTime(d.year, d.month, d.day + days);

    // Streak: start today, or yesterday if today isn't met yet.
    var cursor = met(today) ? today : addDays(today, -1);
    var streak = 0;
    while (met(cursor)) {
      streak++;
      cursor = addDays(cursor, -1);
    }

    var daysMet = 0;
    for (var i = 0; i < windowDays; i++) {
      if (met(addDays(today, -i))) daysMet++;
    }

    return GoalProgress(
      goal: goal,
      todayValue: valueByDay[today] ?? 0,
      streak: streak,
      daysMet: daysMet,
      windowDays: windowDays,
    );
  }
}
