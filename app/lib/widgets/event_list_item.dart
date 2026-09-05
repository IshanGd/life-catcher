import 'package:flutter/material.dart';

import '../models/driver_event.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/relative_time.dart';

/// 05_DESIGN.md §2.3: icon + label + timestamp (+ optional location), with
/// a visually distinct cancelled/false-positive state that must stay
/// visible, never hidden (§2.1, §5).
class EventListItem extends StatelessWidget {
  const EventListItem({super.key, required this.event});

  final DriverEvent event;

  (IconData, Color) get _iconAndColor {
    if (event.cancelled) return (Icons.close_rounded, AppColors.text2);
    return switch (event.kind) {
      EventKind.crashImpact => (Icons.warning_rounded, AppColors.red),
      EventKind.panicButton => (Icons.warning_rounded, AppColors.red),
      EventKind.harshBrake => (Icons.warning_amber_rounded, AppColors.amber),
      EventKind.potholeBump => (Icons.warning_amber_rounded, AppColors.amber),
      EventKind.alcoholFlag => (Icons.warning_amber_rounded, AppColors.amber),
      EventKind.preRideCheckPassed => (Icons.check_circle_rounded, AppColors.green),
      EventKind.panicButtonSelfTest => (Icons.check_circle_rounded, AppColors.green),
      EventKind.firmwareSynced => (Icons.sync_rounded, AppColors.blue),
      EventKind.fatigueNudgeSent => (Icons.bedtime_rounded, AppColors.blue),
      EventKind.normalRiding => (Icons.circle, AppColors.text2),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor;
    final subtitleParts = <String>[formatEventTimestamp(event.timestamp)];
    if (event.location != null) subtitleParts.add(event.location!);
    if (event.cancelled && event.cancelReason != null) subtitleParts.add(event.cancelReason!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: AppTextStyles.body(
                    weight: FontWeight.w600,
                    color: event.cancelled ? AppColors.text2 : AppColors.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitleParts.join(' · '), style: AppTextStyles.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
