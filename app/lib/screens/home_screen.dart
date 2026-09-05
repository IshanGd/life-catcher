import 'package:flutter/material.dart';

import '../models/driver_event.dart';
import '../models/helmet_status.dart';
import '../services/helmet_data_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/relative_time.dart';
import '../widgets/event_list_item.dart';
import '../widgets/fatigue_watch_card.dart';
import '../widgets/safety_score_ring.dart';
import '../widgets/status_pill.dart';
import '../widgets/trend_summary.dart';

/// 05_DESIGN.md §2.1 -- the Home tab, top to bottom exactly as spec'd.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.service, required this.onOpenTrends, required this.onOpenAlerts});

  final HelmetDataService service;
  final VoidCallback onOpenTrends;
  final VoidCallback onOpenAlerts;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<HelmetStatus>(
        stream: service.watchStatus(),
        builder: (context, snapshot) {
          final status = snapshot.data;
          if (status == null) return const Center(child: CircularProgressIndicator(color: AppColors.amber));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _GreetingHeader(greeting: _greeting(), status: status),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: SafetyScoreRing(score: status.safetyScoreToday, deltaVsYesterday: status.safetyScoreDeltaVsYesterday),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  StatusPill(
                    icon: Icons.sports_motorsports_rounded,
                    label: 'Helmet',
                    state: status.helmetWorn ? 'Worn' : 'Not worn',
                    tone: status.helmetWorn ? PillTone.good : PillTone.bad,
                  ),
                  const SizedBox(width: 10),
                  StatusPill(
                    icon: Icons.science_rounded,
                    label: 'Pre-ride',
                    state: switch (status.preRide) {
                      PreRideStatus.passed => 'Passed',
                      PreRideStatus.failed => 'Failed',
                      PreRideStatus.pending => 'Pending',
                    },
                    tone: switch (status.preRide) {
                      PreRideStatus.passed => PillTone.good,
                      PreRideStatus.failed => PillTone.bad,
                      PreRideStatus.pending => PillTone.warning,
                    },
                  ),
                  const SizedBox(width: 10),
                  StatusPill(
                    icon: Icons.bluetooth_rounded,
                    label: 'BLE Link',
                    state: status.bleConnected ? 'Connected' : 'Disconnected',
                    tone: status.bleConnected ? PillTone.good : PillTone.bad,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RISK TREND · 7 DAYS', style: AppTextStyles.eyebrowMono()),
                    const SizedBox(height: 10),
                    TrendSummary(score: status.riskTrend7dScore, improving: status.riskTrendImproving, onDetailsTap: onOpenTrends),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RECENT EVENTS', style: AppTextStyles.eyebrowMono()),
                        GestureDetector(
                          onTap: onOpenAlerts,
                          child: Text('See all', style: AppTextStyles.bodySecondary(color: AppColors.blue, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<List<DriverEvent>>(
                      future: service.recentEvents(limit: 3),
                      builder: (context, eventsSnapshot) {
                        final events = eventsSnapshot.data ?? const [];
                        if (events.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('No events yet', style: AppTextStyles.bodySecondary()),
                          );
                        }
                        return Column(
                          children: [
                            for (var i = 0; i < events.length; i++) ...[
                              if (i > 0) const Divider(color: AppColors.borderSoft, height: 1),
                              EventListItem(event: events[i]),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: FatigueWatchCard(
                  continuous: status.continuousShiftDuration,
                  breakSuggestedIn: status.breakSuggestedIn,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting, required this.status});

  final String greeting;
  final HelmetStatus status;

  @override
  Widget build(BuildContext context) {
    final initials = status.driverName.isNotEmpty ? status.driverName.substring(0, 1).toUpperCase() : '?';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, ${status.driverName}', style: AppTextStyles.heading(size: 20)),
              const SizedBox(height: 4),
              Text(
                'Shift active · ${formatDurationShort(status.shiftDuration)} · ${status.platformName}',
                style: AppTextStyles.bodySecondary(),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.amberDim,
          child: Text(initials, style: AppTextStyles.heading(size: 16, weight: FontWeight.w700, color: AppColors.amber)),
        ),
      ],
    );
  }
}
