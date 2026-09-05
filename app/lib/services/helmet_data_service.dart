import '../models/device_health.dart';
import '../models/driver_event.dart';
import '../models/driver_profile.dart';
import '../models/helmet_status.dart';
import '../models/sos_event.dart';
import '../models/trend.dart';

/// The single seam between hardware and UI (02_ARCHITECTURE.md §5): every
/// screen consumes a [HelmetStatus] stream and a set of history getters
/// from exactly this interface. Swapping [MockHelmetDataService] for a real
/// BLE-backed implementation (Phase 4's actual goal) must never require
/// touching a screen file.
abstract class HelmetDataService {
  /// Live status: helmet worn, pre-ride result, BLE link, battery, safety
  /// score, shift timer. Screens rebuild on every emission.
  Stream<HelmetStatus> watchStatus();

  /// Most recent events, newest first, for the Home screen's short list.
  Future<List<DriverEvent>> recentEvents({int limit = 3});

  /// The full reverse-chronological audit trail for the Alerts tab.
  Future<List<DriverEvent>> alertHistory();

  /// 7-day (Mon-Sun) safety score series for the Trends tab.
  Future<List<TrendPoint>> weeklyTrend();

  /// Harsh-event rates per 100km, by type, for the Trends tab.
  Future<List<HarshEventRate>> harshEventBreakdown();

  /// 7-day helmet-wear and pre-ride-check compliance for the Trends tab.
  Future<ComplianceStats> complianceStats();

  Future<DriverProfile> driverProfile();

  Future<DeviceHealth> deviceHealth();

  /// Fires once per SOS that finishes fusion-confirmed and non-cancelled
  /// (firmware: SosStateMachine's `confirmed: true` event,
  /// 02_ARCHITECTURE.md §4). [SosRelay] (lib/logic/sos_relay.dart) is the
  /// only consumer -- everything from here is the phone-side relay (ADR-1).
  Stream<SosEvent> watchConfirmedSosEvents();

  /// Log a completed SOS dispatch back into the event history so it's part
  /// of the audit trail (03_RULES.md: never let an SOS outcome go
  /// unlogged), the same way a cancellation always gets its own event.
  void recordSosDispatchOutcome(DriverEvent event);
}
