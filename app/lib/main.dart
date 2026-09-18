import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'services/ble_helmet_data_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmartHelmetApp());
}

/// Companion app (driver-facing), 05_DESIGN.md / 02_ARCHITECTURE.md §5.
///
/// Backed by [BleHelmetDataService] -- real NimBLE notifications from
/// `firmware/src/ble/gatt_server.cpp`, Phase 2 hardware now exists and is
/// bring-up-verified. [MockHelmetDataService] (services/mock_helmet_data_
/// service.dart) still exists for screen development without a helmet in
/// range; swap it back in here if that's what's needed.
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
      home: RootShell(service: BleHelmetDataService()),
    );
  }
}
