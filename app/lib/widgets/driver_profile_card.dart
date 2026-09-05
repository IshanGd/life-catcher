import 'package:flutter/material.dart';

import '../models/driver_profile.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// 05_DESIGN.md §2.4.1: name, avatar initials, platform, vehicle type,
/// device ID, pairing status, emergency contact status (Set / Not set).
class DriverProfileCard extends StatelessWidget {
  const DriverProfileCard({super.key, required this.profile});

  final DriverProfile profile;

  String get _pairingLabel => switch (profile.pairingStatus) {
        PairingStatus.paired => 'Paired',
        PairingStatus.pairing => 'Pairing…',
        PairingStatus.unpaired => 'Not paired',
      };

  Color get _pairingColor => switch (profile.pairingStatus) {
        PairingStatus.paired => AppColors.green,
        PairingStatus.pairing => AppColors.amber,
        PairingStatus.unpaired => AppColors.text2,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.amberDim,
              child: Text(
                profile.avatarInitials,
                style: AppTextStyles.heading(size: 16, weight: FontWeight.w700, color: AppColors.amber),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: AppTextStyles.heading(size: 18)),
                  const SizedBox(height: 2),
                  Text('${profile.platform} · ${profile.vehicleType}', style: AppTextStyles.bodySecondary()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 14),
        _row('Device ID', profile.deviceId, mono: true),
        const SizedBox(height: 10),
        _row('Pairing', _pairingLabel, valueColor: _pairingColor),
        const SizedBox(height: 10),
        _row(
          'Emergency contact',
          profile.emergencyContactSet ? '${profile.emergencyContactName} ✓' : 'Not set',
          valueColor: profile.emergencyContactSet ? AppColors.green : AppColors.red,
        ),
        if (profile.emergencyContactSet) ...[
          const SizedBox(height: 10),
          _row('Contact number', profile.emergencyContactPhone!, mono: true),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool mono = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySecondary()),
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
