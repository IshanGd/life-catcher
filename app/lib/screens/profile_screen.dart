import 'package:flutter/material.dart';

import '../models/device_health.dart';
import '../models/driver_profile.dart';
import '../models/sos_event.dart';
import '../services/helmet_data_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/device_health_card.dart';
import '../widgets/driver_profile_card.dart';

/// 05_DESIGN.md §2.4 -- driver profile card + device health card.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.service, this.onTriggerTestSos});

  final HelmetDataService service;

  /// Debug-only affordance to exercise the SOS relay without real
  /// hardware (04_PHASES.md Phase 2 isn't built yet). Null on a real
  /// BLE-backed build -- see RootShell._debugTriggerSos.
  final void Function(SosTriggerType)? onTriggerTestSos;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Profile', style: AppTextStyles.heading(size: 24)),
          const SizedBox(height: 16),
          FutureBuilder<DriverProfile>(
            future: service.driverProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              if (profile == null) return const SizedBox.shrink();
              return AppCard(child: DriverProfileCard(profile: profile));
            },
          ),
          const SizedBox(height: 14),
          Text('DEVICE HEALTH', style: AppTextStyles.eyebrowMono()),
          const SizedBox(height: 10),
          FutureBuilder<DeviceHealth>(
            future: service.deviceHealth(),
            builder: (context, snapshot) {
              final health = snapshot.data;
              if (health == null) return const SizedBox.shrink();
              return AppCard(child: DeviceHealthCard(health: health));
            },
          ),
          if (onTriggerTestSos != null) ...[
            const SizedBox(height: 14),
            Text('SELF-TEST', style: AppTextStyles.eyebrowMono()),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No hardware yet — these simulate a fusion-confirmed SOS arriving over BLE, the same way the real helmet will once Phase 2 lands.',
                    style: AppTextStyles.bodySecondary(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onTriggerTestSos!(SosTriggerType.crashImpact),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                          child: const Text('Test crash SOS'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onTriggerTestSos!(SosTriggerType.panicButton),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber, side: const BorderSide(color: AppColors.amber)),
                          child: const Text('Test panic SOS'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
