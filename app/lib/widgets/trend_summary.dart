import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.1.4: compact score + direction + a "Details" link
/// through to the Trends tab.
class TrendSummary extends StatelessWidget {
  const TrendSummary({
    super.key,
    required this.score,
    required this.improving,
    required this.onDetailsTap,
  });

  final int score;
  final bool improving;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    final color = improving ? AppColors.green : AppColors.red;
    return Row(
      children: [
        Text('$score', style: AppTextStyles.heading(size: 22, weight: FontWeight.w700)),
        const SizedBox(width: 8),
        Icon(improving ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          improving ? 'improving' : 'declining',
          style: AppTextStyles.bodySecondary(color: color, weight: FontWeight.w600),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onDetailsTap,
          child: Text('Details', style: AppTextStyles.bodySecondary(color: AppColors.blue, weight: FontWeight.w600)),
        ),
      ],
    );
  }
}
