import 'package:flutter/material.dart';

import '../models/trend.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.2.2: harsh-event breakdown by type, as a rate per
/// 100km -- normalizing by distance is intentional, never a raw count.
class RateBreakdownList extends StatelessWidget {
  const RateBreakdownList({super.key, required this.rates});

  final List<HarshEventRate> rates;

  @override
  Widget build(BuildContext context) {
    final maxRate = rates.fold<double>(0.1, (m, r) => r.ratePer100km > m ? r.ratePer100km : m);
    return Column(
      children: [
        for (final r in rates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text(r.label, style: AppTextStyles.bodySecondary())),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: r.ratePer100km / maxRate,
                      minHeight: 6,
                      backgroundColor: AppColors.surface3,
                      valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: Text(
                    '${r.ratePer100km.toStringAsFixed(1)}/100km',
                    style: AppTextStyles.caption(color: AppColors.text1),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
