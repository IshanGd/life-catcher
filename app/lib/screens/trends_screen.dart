import 'package:flutter/material.dart';

import '../models/trend.dart';
import '../services/helmet_data_service.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../widgets/compliance_stat_row.dart';
import '../widgets/rate_breakdown_list.dart';
import '../widgets/weekly_trend_chart.dart';

/// 05_DESIGN.md §2.2 -- the Trends tab.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key, required this.service});

  final HelmetDataService service;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Trends', style: AppTextStyles.heading(size: 24)),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEEKLY RISK SCORE', style: AppTextStyles.eyebrowMono()),
                const SizedBox(height: 12),
                FutureBuilder<List<TrendPoint>>(
                  future: service.weeklyTrend(),
                  builder: (context, snapshot) {
                    final points = snapshot.data ?? const [];
                    if (points.isEmpty) return const SizedBox(height: 160);
                    return WeeklyTrendChart(points: points);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HARSH EVENTS / 100KM', style: AppTextStyles.eyebrowMono()),
                const SizedBox(height: 14),
                FutureBuilder<List<HarshEventRate>>(
                  future: service.harshEventBreakdown(),
                  builder: (context, snapshot) => RateBreakdownList(rates: snapshot.data ?? const []),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('COMPLIANCE · 7 DAYS', style: AppTextStyles.eyebrowMono()),
          const SizedBox(height: 10),
          FutureBuilder<ComplianceStats>(
            future: service.complianceStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              if (stats == null) return const SizedBox.shrink();
              return ComplianceStatRow(stats: stats);
            },
          ),
        ],
      ),
    );
  }
}
