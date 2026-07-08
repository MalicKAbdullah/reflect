import 'package:flutter_test/flutter_test.dart';
import 'package:reflect/src/features/entries/models/journal_entry.dart';
import 'package:reflect/src/features/goals/models/writing_goal.dart';
import 'package:reflect/src/features/goals/services/goal_progress.dart';

JournalEntry entry(String id, DateTime createdAt, {String body = 'w'}) =>
    JournalEntry(
      id: id,
      body: body,
      mood: 3,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

void main() {
  group('WritingGoal', () {
    test('encode/decode round-trips', () {
      const goal = WritingGoal(metric: GoalMetric.words, target: 250);
      expect(WritingGoal.decode(goal.encode()), goal);
      const daily = WritingGoal(metric: GoalMetric.entries, target: 1);
      expect(WritingGoal.decode(daily.encode()), daily);
    });

    test('decode rejects junk', () {
      expect(WritingGoal.decode(null), isNull);
      expect(WritingGoal.decode(''), isNull);
      expect(WritingGoal.decode('entries'), isNull);
      expect(WritingGoal.decode('pages:3'), isNull);
      expect(WritingGoal.decode('words:0'), isNull);
      expect(WritingGoal.decode('words:abc'), isNull);
    });

    test('describes itself in plain language', () {
      expect(
        const WritingGoal(metric: GoalMetric.entries, target: 1).description,
        'Write 1 entry a day',
      );
      expect(
        const WritingGoal(metric: GoalMetric.words, target: 200).description,
        'Write 200 words a day',
      );
    });
  });

  group('GoalProgress — entries metric', () {
    const goal = WritingGoal(metric: GoalMetric.entries, target: 2);
    final now = DateTime(2026, 7, 5, 14);

    test('counts today and reports fraction', () {
      final progress = GoalProgress.compute(
        [entry('a', DateTime(2026, 7, 5, 8))],
        goal,
        now: now,
      );
      expect(progress.todayValue, 1);
      expect(progress.metToday, isFalse);
      expect(progress.fraction, 0.5);
    });

    test('streak counts consecutive met days ending today', () {
      final progress = GoalProgress.compute(
        [
          entry('a1', DateTime(2026, 7, 5, 8)),
          entry('a2', DateTime(2026, 7, 5, 9)),
          entry('b1', DateTime(2026, 7, 4, 8)),
          entry('b2', DateTime(2026, 7, 4, 9)),
          // 3 July missed (only one entry).
          entry('c1', DateTime(2026, 7, 3, 8)),
          entry('d1', DateTime(2026, 7, 2, 8)),
          entry('d2', DateTime(2026, 7, 2, 9)),
        ],
        goal,
        now: now,
      );
      expect(progress.streak, 2);
      expect(progress.daysMet, 3); // 5th, 4th and 2nd within the window.
    });

    test('an unfinished today defers to yesterday for the streak', () {
      final progress = GoalProgress.compute(
        [
          entry('b1', DateTime(2026, 7, 4, 8)),
          entry('b2', DateTime(2026, 7, 4, 9)),
          entry('c1', DateTime(2026, 7, 3, 8)),
          entry('c2', DateTime(2026, 7, 3, 9)),
        ],
        goal,
        now: now,
      );
      expect(progress.todayValue, 0);
      expect(progress.streak, 2);
    });

    test('no entries at all', () {
      final progress = GoalProgress.compute(const [], goal, now: now);
      expect(progress.todayValue, 0);
      expect(progress.streak, 0);
      expect(progress.daysMet, 0);
      expect(progress.fraction, 0);
    });
  });

  group('GoalProgress — words metric', () {
    const goal = WritingGoal(metric: GoalMetric.words, target: 10);
    final now = DateTime(2026, 7, 5, 14);

    test('sums words across entries, title included', () {
      final progress = GoalProgress.compute(
        [
          entry('a', DateTime(2026, 7, 5, 8), body: 'one two three four'),
          JournalEntry(
            id: 'b',
            title: 'five six',
            body: 'seven eight nine ten',
            mood: 3,
            createdAt: DateTime(2026, 7, 5, 9),
            updatedAt: DateTime(2026, 7, 5, 9),
          ),
        ],
        goal,
        now: now,
      );
      expect(progress.todayValue, 10);
      expect(progress.metToday, isTrue);
      expect(progress.fraction, 1.0);
    });

    test('fraction caps at 1.0 when over target', () {
      final progress = GoalProgress.compute(
        [
          entry(
            'a',
            DateTime(2026, 7, 5, 8),
            body: List.filled(25, 'word').join(' '),
          ),
        ],
        goal,
        now: now,
      );
      expect(progress.todayValue, 25);
      expect(progress.fraction, 1.0);
    });
  });
}
