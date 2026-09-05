import 'package:flutter/material.dart';

/// 05_DESIGN.md §2, §5: exactly 4 tabs (Home/Trends/Alerts/Profile) --
/// don't add a 5th without confirming it belongs there over nesting it.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.show_chart_rounded), selectedIcon: Icon(Icons.show_chart_rounded), label: 'Trends'),
        NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}
