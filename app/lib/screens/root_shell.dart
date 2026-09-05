import 'package:flutter/material.dart';

import '../services/helmet_data_service.dart';
import '../widgets/bottom_nav.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'trends_screen.dart';

/// 05_DESIGN.md §2: 4-tab bottom nav (Home/Trends/Alerts/Profile) over one
/// [HelmetDataService] instance -- the single seam (02_ARCHITECTURE.md §5).
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.service});

  final HelmetDataService service;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(service: widget.service, onOpenTrends: () => _goTo(1), onOpenAlerts: () => _goTo(2)),
      TrendsScreen(service: widget.service),
      AlertsScreen(service: widget.service),
      ProfileScreen(service: widget.service),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
