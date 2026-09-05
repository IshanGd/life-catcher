import 'package:flutter/material.dart';

import '../models/device_health.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/relative_time.dart';

/// Shared between the driver app's Profile tab and the Fleet-Ops support
/// view (05_DESIGN.md §2.4.2, §3.3) -- battery, last sync, firmware
/// version, alcohol sensor calibration age. Surfacing calibration recency
/// is a deliberate trust signal (§2.4), kept even once uncalibrated.
class DeviceHealthCard extends StatelessWidget {
  const DeviceHealthCard({super.key, required this.health});

  final DeviceHealth health;

  Color _batteryColor(int? pct) {
    if (pct == null) return AppColors.text2;
    if (pct < 20) return AppColors.red;
    if (pct < 40) return AppColors.amber;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          Icons.battery_charging_full_rounded,
          'Battery',
          health.batteryPct != null ? '${health.batteryPct}%' : 'Unknown',
          valueColor: _batteryColor(health.batteryPct),
        ),
        const SizedBox(height: 12),
        _row(Icons.sync_rounded, 'Last sync', formatRelativeAgo(health.lastSync)),
        const SizedBox(height: 12),
        _row(Icons.memory_rounded, 'Firmware', health.firmwareVersion, mono: true),
        const SizedBox(height: 12),
        _row(
          Icons.science_rounded,
          'Alcohol sensor calibration',
          health.alcoholCalibrationAge != null ? '${health.alcoholCalibrationAge!.inDays}d ago' : 'Not calibrated',
          valueColor: health.alcoholCalibrationAge == null ? AppColors.amber : null,
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor, bool mono = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.text2),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.bodySecondary())),
        Text(
          value,
          style: mono
              ? AppTextStyles.tagMono(color: valueColor ?? AppColors.text1)
              : AppTextStyles.body(weight: FontWeight.w600, color: valueColor ?? AppColors.text1),
        ),
      ],
    );
  }
}
