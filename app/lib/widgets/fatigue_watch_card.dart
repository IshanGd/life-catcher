import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/relative_time.dart';

/// 05_DESIGN.md §2.1.6: continuous-shift-duration readout with a break
/// suggestion countdown, e.g. "1h 50m continuous · Break suggested in 1h 10m".
class FatigueWatchCard extends StatelessWidget {
  const FatigueWatchCard({
    super.key,
    required this.continuous,
    required this.breakSuggestedIn,
  });

  final Duration continuous;
  final Duration breakSuggestedIn;

  @override
  Widget build(BuildContext context) {
    final urgent = breakSuggestedIn <= const Duration(minutes: 15);
    return Row(
      children: [
        Icon(Icons.bedtime_rounded, size: 20, color: urgent ? AppColors.amber : AppColors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${formatDurationShort(continuous)} continuous', style: AppTextStyles.body(weight: FontWeight.w600)),
                TextSpan(text: '  ·  Break suggested in ', style: AppTextStyles.bodySecondary()),
                TextSpan(
                  text: formatDurationShort(breakSuggestedIn),
                  style: AppTextStyles.bodySecondary(
                    weight: FontWeight.w600,
                    color: urgent ? AppColors.amber : AppColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
