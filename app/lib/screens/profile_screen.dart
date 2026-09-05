import 'package:flutter/material.dart';

import '../models/device_health.dart';
import '../models/driver_profile.dart';
import '../services/helmet_data_service.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../widgets/device_health_card.dart';
import '../widgets/driver_profile_card.dart';

/// 05_DESIGN.md §2.4 -- driver profile card + device health card.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.service});

  final HelmetDataService service;

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
        ],
      ),
    );
  }
}
