import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §1: "Status is always color + icon + text together, never
/// color alone." §2.1.3: three of these in a row (Helmet / Pre-ride / BLE).
enum PillTone { good, bad, neutral, warning }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.state,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String state;
  final PillTone tone;

  Color get _color => switch (tone) {
        PillTone.good => AppColors.green,
        PillTone.bad => AppColors.red,
        PillTone.warning => AppColors.amber,
        PillTone.neutral => AppColors.text2,
      };

  Color get _dim => switch (tone) {
        PillTone.good => AppColors.greenDim,
        PillTone.bad => AppColors.redDim,
        PillTone.warning => AppColors.amberDim,
        PillTone.neutral => AppColors.surface3,
      };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _dim,
          borderRadius: BorderRadius.circular(AppRadii.cardSmall),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _color),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.caption(), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(
              state,
              style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: _color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
