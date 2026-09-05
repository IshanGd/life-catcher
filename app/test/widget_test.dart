// Smoke test: the app boots, shows the Home tab, and the bottom nav
// switches to each of the other three tabs without throwing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_helmet_app/main.dart';

void main() {
  testWidgets('app boots on Home and all 4 tabs are reachable', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartHelmetApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Arjun'), findsWidgets);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    for (final tab in const ['Trends', 'Alerts', 'Profile']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(tab), findsWidgets);
    }
  });
}
