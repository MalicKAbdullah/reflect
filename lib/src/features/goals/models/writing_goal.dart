import 'package:flutter/foundation.dart';

/// What a daily writing goal counts.
enum GoalMetric { entries, words }

/// An optional daily writing goal (e.g. "1 entry a day", "200 words a day").
@immutable
final class WritingGoal {
  const WritingGoal({required this.metric, required this.target})
      : assert(target > 0, 'target must be positive');

  final GoalMetric metric;
  final int target;

  /// Compact persisted form, e.g. "entries:1" or "words:200".
  String encode() => '${metric.name}:$target';

  static WritingGoal? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final metric = GoalMetric.values.asNameMap()[parts[0]];
    final target = int.tryParse(parts[1]);
    if (metric == null || target == null || target <= 0) return null;
    return WritingGoal(metric: metric, target: target);
  }

  String get unitLabel => metric == GoalMetric.entries
      ? (target == 1 ? 'entry' : 'entries')
      : 'words';

  String get description => 'Write $target $unitLabel a day';

  @override
  bool operator ==(Object other) =>
      other is WritingGoal && other.metric == metric && other.target == target;

  @override
  int get hashCode => Object.hash(metric, target);
}
