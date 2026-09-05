import 'package:flutter/material.dart';

import '../models/trend.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.2.3: helmet wear rate (%) and pre-ride checks completed
/// (fraction, e.g. "14/14") -- percentage/fraction stat pairs.
class ComplianceStatRow extends StatelessWidget {
  const ComplianceStatRow({super.key, required this.stats});

  final ComplianceStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Helmet wear rate',
            value: '${stats.helmetWearRatePct}%',
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat(
            label: 'Pre-ride checks',
            value: '${stats.preRideChecksCompleted}/${stats.preRideChecksTotal}',
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface2,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.heading(size: 24, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
