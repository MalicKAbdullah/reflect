import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';

/// Entries written per week over the last 8 weeks; the current week is
/// highlighted.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({required this.weeks, super.key});

  final List<WeekCount> weeks;

  @override
  Widget build(BuildContext context) {
    final labelFormat = DateFormat.Md();
    return MiniBarChart(
      height: 132,
      values: [for (final w in weeks) w.count.toDouble()],
      labels: [for (final w in weeks) labelFormat.format(w.weekStart)],
      highlightIndex: weeks.length - 1,
    );
  }
}
