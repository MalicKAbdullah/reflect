import 'package:core_theme/core_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';

/// Entries written per week over the last 8 weeks.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({required this.weeks, super.key});

  final List<WeekCount> weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.primary;
    final labelFormat = DateFormat.Md();
    final maxCount =
        weeks.fold<int>(0, (max, w) => w.count > max ? w.count : max);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipMargin: 2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                rod.toY.toInt().toString(),
                theme.textTheme.labelSmall!,
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles()),
            rightTitles: const AxisTitles(sideTitles: SideTitles()),
            leftTitles: const AxisTitles(sideTitles: SideTitles()),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      labelFormat.format(weeks[index].weekStart),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < weeks.length; i++)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators: weeks[i].count > 0 ? [0] : const [],
                barRods: [
                  BarChartRodData(
                    toY: weeks[i].count.toDouble(),
                    width: 18,
                    color: weeks[i].count == 0
                        ? barColor.withValues(alpha: 0.15)
                        : barColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
