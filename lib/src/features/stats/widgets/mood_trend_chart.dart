import 'package:core_theme/core_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reflect/src/features/stats/services/journal_stats.dart';

/// Average mood per day over the last 30 days.
class MoodTrendChart extends StatelessWidget {
  const MoodTrendChart({required this.trend, super.key});

  final List<DailyMood> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[
      for (var i = 0; i < trend.length; i++)
        if (trend[i].average != null) FlSpot(i.toDouble(), trend[i].average!),
    ];
    if (spots.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No mood data yet',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }
    final lineColor = theme.colorScheme.primary;
    final labelFormat = DateFormat.Md();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0.5,
          maxY: 5.5,
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles()),
            rightTitles: const AxisTitles(sideTitles: SideTitles()),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0 || value < 1 || value > 5) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: theme.textTheme.labelSmall,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      labelFormat.format(trend[index].date),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: lineColor,
              barWidth: 2.5,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 2.5,
                  color: lineColor,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
