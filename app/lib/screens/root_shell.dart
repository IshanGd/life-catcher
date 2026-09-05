import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/sos_relay.dart';
import '../models/driver_event.dart';
import '../models/sos_dispatch.dart';
import '../models/sos_event.dart';
import '../services/helmet_data_service.dart';
import '../services/location_provider.dart';
import '../services/mock_helmet_data_service.dart';
import '../services/sos_transport.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sos_dispatch_banner.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'trends_screen.dart';

/// 05_DESIGN.md §2: 4-tab bottom nav (Home/Trends/Alerts/Profile) over one
/// [HelmetDataService] instance -- the single seam (02_ARCHITECTURE.md §5).
///
/// Also owns the [SosRelay] (01_REQUIREMENTS.md SOS relay, 04_PHASES.md
/// Phase 4): listens for the service's confirmed-SOS events, dispatches
/// them via phone GPS + data/SMS, and surfaces the live status as a banner
/// above every tab so it survives a tab switch.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.service});

  final HelmetDataService service;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  SosRelay? _sosRelay;
  SosDispatchRecord? _activeDispatch;
  StreamSubscription<SosEvent>? _sosEventSub;
  StreamSubscription<SosDispatchRecord>? _dispatchSub;

  @override
  void initState() {
    super.initState();
    _initSosRelay();
  }

  Future<void> _initSosRelay() async {
    final profile = await widget.service.driverProfile();
    final relay = SosRelay(
      locationProvider: MockLocationProvider(),
      transport: MockSosTransport(),
      driverName: profile.name,
      emergencyContactName: profile.emergencyContactName ?? 'emergency services',
      emergencyContactPhone: profile.emergencyContactPhone ?? '',
    );
    _dispatchSub = relay.dispatches.listen(_onDispatchUpdate);
    _sosEventSub = widget.service.watchConfirmedSosEvents().listen(relay.dispatch);
    _sosRelay = relay;
  }

  void _onDispatchUpdate(SosDispatchRecord record) {
    if (!mounted) return;
    setState(() => _activeDispatch = record);
    if (record.status == SosDispatchStatus.sent || record.status == SosDispatchStatus.failed) {
      widget.service.recordSosDispatchOutcome(_toDriverEvent(record));
    }
  }

  DriverEvent _toDriverEvent(SosDispatchRecord record) {
    final sent = record.status == SosDispatchStatus.sent;
    final label = record.event.type == SosTriggerType.crashImpact ? 'Impact alert' : 'Panic button SOS';
    return DriverEvent(
      id: 'sos-${record.event.timestampDeviceMs}',
      kind: record.event.type == SosTriggerType.crashImpact ? EventKind.crashImpact : EventKind.panicButton,
      timestamp: DateTime.now(),
      description: sent ? '$label — emergency contact notified' : '$label — relay failed, retry needed',
      location: record.location?.toDisplayString(),
    );
  }

  void _dismissDispatch() => setState(() => _activeDispatch = null);

  void _retryDispatch() {
    final relay = _sosRelay;
    final record = _activeDispatch;
    if (relay != null && record != null) relay.dispatch(record.event);
  }

  /// Test/debug only -- see MockHelmetDataService.triggerTestSos. Null
  /// (hides the debug affordance) if the service isn't the mock.
  void Function(SosTriggerType)? get _debugTriggerSos {
    final service = widget.service;
    if (service is! MockHelmetDataService) return null;
    return service.triggerTestSos;
  }

  @override
  void dispose() {
    _sosEventSub?.cancel();
    _dispatchSub?.cancel();
    _sosRelay?.dispose();
    super.dispose();
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(service: widget.service, onOpenTrends: () => _goTo(1), onOpenAlerts: () => _goTo(2)),
      TrendsScreen(service: widget.service),
      AlertsScreen(service: widget.service),
      ProfileScreen(service: widget.service, onTriggerTestSos: _debugTriggerSos),
    ];

    final activeDispatch = _activeDispatch;
    return Scaffold(
      body: Column(
        children: [
          if (activeDispatch != null)
            SosDispatchBanner(
              record: activeDispatch,
              onDismiss: _dismissDispatch,
              onRetry: activeDispatch.status == SosDispatchStatus.failed ? _retryDispatch : null,
            ),
          Expanded(child: IndexedStack(index: _index, children: screens)),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _index, onTap: _goTo),
    );
  }
}
