import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'services/mock_helmet_data_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmartHelmetApp());
}

/// Companion app (driver-facing), 05_DESIGN.md / 02_ARCHITECTURE.md §5.
///
/// Backed by [MockHelmetDataService] for now -- the real Phase 4 work is
/// swapping that for a BLE-backed [HelmetDataService] implementation once
/// Phase 2 hardware exists, without touching any screen file.
class SmartHelmetApp extends StatelessWidget {
  const SmartHelmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Helmet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: RootShell(service: MockHelmetDataService()),
    );
  }
}
