import 'package:flutter/material.dart';

import '../models/driver_event.dart';
import '../services/helmet_data_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/event_list_item.dart';

/// 05_DESIGN.md §2.3 -- full reverse-chronological audit trail, including
/// cancelled events. Every BLE event_type gets a row style here.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.service});

  final HelmetDataService service;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<DriverEvent>>(
        future: service.alertHistory(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('Alerts', style: AppTextStyles.heading(size: 24)),
              const SizedBox(height: 16),
              if (events.isEmpty)
                Text('No events yet', style: AppTextStyles.bodySecondary())
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < events.length; i++) ...[
                        if (i > 0) const Divider(color: AppColors.borderSoft, height: 1),
                        EventListItem(event: events[i]),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
