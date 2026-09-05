import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/trend.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.2.1: 7-day (M-S) line chart of safety score.
class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSoft, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length || (value - i).abs() > 0.01) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].label, style: AppTextStyles.caption()),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface3,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('${s.y.toInt()}', AppTextStyles.body(weight: FontWeight.w600)))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].score.toDouble())],
              isCurved: true,
              color: AppColors.amber,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppColors.amberDim),
            ),
          ],
        ),
      ),
    );
  }
}
