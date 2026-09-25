import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/conservation_report.dart';
import '../../data/category_labels.dart';

class IncidentCategoryChart extends StatelessWidget {
  const IncidentCategoryChart({super.key, required this.report});

  final ConservationReport report;

  @override
  Widget build(BuildContext context) {
    final categories = report.criteria?.categories ??
        (report.incidentCounts.keys.toList()
          ..sort((a, b) => a.index.compareTo(b.index)));
    if (categories.isEmpty) {
      return const _ChartEmpty(message: 'No incident categories selected.');
    }
    final maxCount = categories.fold<int>(0, (max, category) {
      final count = report.incidentCounts[category] ?? 0;
      return count > max ? count : max;
    });

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() * 1.2,
          minY: 0,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                // One label per category; without this fl_chart picks a default
                // interval that can skip or duplicate category labels.
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= categories.length ||
                      value != index.toDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _short(categories[index]),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < categories.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (report.incidentCounts[categories[i]] ?? 0).toDouble(),
                    color: AppColors.primary,
                    width: 18,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _short(IncidentCategory category) => switch (category) {
        IncidentCategory.poaching => 'Poach',
        IncidentCategory.animalInjury => 'Injury',
        IncidentCategory.humanWildlifeConflict => 'Conflict',
        IncidentCategory.illegalLogging => 'Logging',
        IncidentCategory.other => 'Other',
      };
}

class ConflictTrendChart extends StatelessWidget {
  const ConflictTrendChart({super.key, required this.report});

  final ConservationReport report;

  @override
  Widget build(BuildContext context) {
    final points = report.conflictTrends;
    if (points.isEmpty) {
      return const _ChartEmpty(message: 'No conflict alerts in this period.');
    }
    final maxCount = points.fold<int>(
        0, (max, point) => point.count > max ? point.count : max);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() * 1.2,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: points.length <= 6
                    ? 1.0
                    : (points.length / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= points.length ||
                      value != index.toDouble()) {
                    return const SizedBox.shrink();
                  }
                  final start = points[index].periodStart;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${start.month}/${start.day}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: false,
              color: AppColors.secondary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].count.toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

String leadingCategoryLabel(ConservationReport report) {
  final entries = report.incidentCounts.entries.toList();
  if (entries.isEmpty) return incidentCategoryLabel(IncidentCategory.other);
  entries.sort((a, b) {
    final byCount = b.value.compareTo(a.value);
    if (byCount != 0) return byCount;
    return a.key.index.compareTo(b.key.index);
  });
  return incidentCategoryLabel(entries.first.key);
}

int leadingCategoryCount(ConservationReport report) {
  if (report.incidentCounts.isEmpty) return 0;
  return report.incidentCounts.values.reduce((a, b) => a > b ? a : b);
}
