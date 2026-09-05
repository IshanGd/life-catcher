import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.1.2: "the single most prominent element on the screen."
/// Circular 0-100 gauge with a delta line ("▲ 5 pts vs. yesterday").
class SafetyScoreRing extends StatelessWidget {
  const SafetyScoreRing({
    super.key,
    required this.score,
    required this.deltaVsYesterday,
    this.size = 168,
  });

  final int score;
  final int deltaVsYesterday;
  final double size;

  @override
  Widget build(BuildContext context) {
    final improving = deltaVsYesterday >= 0;
    final deltaColor = improving ? AppColors.green : AppColors.red;
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: score.clamp(0, 100) / 100,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surface3,
                  valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$score', style: AppTextStyles.statLarge()),
                  Text('/ 100', style: AppTextStyles.bodySecondary()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(improving ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: deltaColor),
            const SizedBox(width: 4),
            Text(
              '${deltaVsYesterday.abs()} pts vs. yesterday',
              style: AppTextStyles.bodySecondary(color: deltaColor, weight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
