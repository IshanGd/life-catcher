import 'dart:async';

import '../models/device_health.dart';
import '../models/driver_event.dart';
import '../models/driver_profile.dart';
import '../models/helmet_status.dart';
import '../models/trend.dart';
import 'helmet_data_service.dart';

/// Sample data standing in for the real BLE pipeline (Phase 2 hardware) and
/// phone-side scoring/trend computation (Phase 4's remaining app-side
/// work). This is the "mockup with sample data" 04_PHASES.md Phase 0
/// describes -- it never existed as a committed mockup in this repo, so
/// this class is that starting point, built directly against the real
/// [HelmetDataService] seam instead of a throwaway prototype.
class MockHelmetDataService implements HelmetDataService {
  MockHelmetDataService()
      : _shiftStart = DateTime.now().subtract(const Duration(hours: 2, minutes: 14)),
        _lastBreakAt = DateTime.now().subtract(const Duration(hours: 1, minutes: 50));

  final DateTime _shiftStart;
  final DateTime _lastBreakAt;

  /// "Break suggested" fires once continuous riding hits this long
  /// (05_DESIGN.md §2.1 fatigue-watch countdown; concept-only per
  /// 04_PHASES.md, so this threshold is illustrative, not a tuned value).
  static const _continuousRideBreakThreshold = Duration(hours: 3);

  @override
  Stream<HelmetStatus> watchStatus() async* {
    yield _statusNow();
    yield* Stream.periodic(const Duration(seconds: 1), (_) => _statusNow());
  }

  HelmetStatus _statusNow() {
    final now = DateTime.now();
    final continuous = now.difference(_lastBreakAt);
    final breakSuggestedIn = _continuousRideBreakThreshold - continuous;
    return HelmetStatus(
      driverName: 'Arjun',
      platformName: 'Rapido',
      shiftDuration: now.difference(_shiftStart),
      helmetWorn: true,
      preRide: PreRideStatus.passed,
      bleConnected: true,
      batteryPct: 78,
      firmwareVersion: '0.1.0-phase2',
      safetyScoreToday: 87,
      safetyScoreDeltaVsYesterday: 5,
      riskTrend7dScore: 82,
      riskTrendImproving: true,
      continuousShiftDuration: continuous,
      breakSuggestedIn: breakSuggestedIn.isNegative ? Duration.zero : breakSuggestedIn,
    );
  }

  @override
  Future<List<DriverEvent>> recentEvents({int limit = 3}) async {
    final all = await alertHistory();
    return all.take(limit).toList();
  }

  @override
  Future<List<DriverEvent>> alertHistory() async {
    final now = DateTime.now();
    return [
      DriverEvent(
        id: 'evt-6',
        kind: EventKind.harshBrake,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 46)),
        description: 'Harsh braking detected',
        location: 'MG Road',
      ),
      DriverEvent(
        id: 'evt-5',
        kind: EventKind.crashImpact,
        timestamp: now.subtract(const Duration(hours: 3, minutes: 2)),
        description: 'Impact alert — cancelled by driver',
        location: 'Outer Ring Road',
        cancelled: true,
        cancelReason: 'false positive, pothole',
      ),
      DriverEvent(
        id: 'evt-4',
        kind: EventKind.preRideCheckPassed,
        timestamp: now.subtract(const Duration(hours: 4, minutes: 20)),
        description: 'Pre-ride check passed',
      ),
      DriverEvent(
        id: 'evt-3',
        kind: EventKind.fatigueNudgeSent,
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
        description: 'Fatigue nudge sent — 3h continuous riding',
      ),
      DriverEvent(
        id: 'evt-2',
        kind: EventKind.firmwareSynced,
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        description: 'Firmware synced',
      ),
      DriverEvent(
        id: 'evt-1',
        kind: EventKind.panicButtonSelfTest,
        timestamp: now.subtract(const Duration(days: 2)),
        description: 'Panic button self-test passed',
      ),
    ];
  }

  @override
  Future<List<TrendPoint>> weeklyTrend() async => const [
        TrendPoint(label: 'Mon', score: 74),
        TrendPoint(label: 'Tue', score: 78),
        TrendPoint(label: 'Wed', score: 71),
        TrendPoint(label: 'Thu', score: 80),
        TrendPoint(label: 'Fri', score: 83),
        TrendPoint(label: 'Sat', score: 79),
        TrendPoint(label: 'Sun', score: 87),
      ];

  @override
  Future<List<HarshEventRate>> harshEventBreakdown() async => const [
        HarshEventRate(label: 'Harsh braking', ratePer100km: 2.1),
        HarshEventRate(label: 'Harsh acceleration', ratePer100km: 1.4),
        HarshEventRate(label: 'Cornering anomalies', ratePer100km: 0.6),
      ];

  @override
  Future<ComplianceStats> complianceStats() async => const ComplianceStats(
        helmetWearRatePct: 96,
        preRideChecksCompleted: 14,
        preRideChecksTotal: 14,
      );

  @override
  Future<DriverProfile> driverProfile() async => const DriverProfile(
        name: 'Arjun',
        avatarInitials: 'AR',
        platform: 'Rapido',
        vehicleType: 'Two-wheeler',
        deviceId: 'SmartHelmet-0001',
        pairingStatus: PairingStatus.paired,
        emergencyContactSet: true,
      );

  @override
  Future<DeviceHealth> deviceHealth() async => DeviceHealth(
        batteryPct: 78,
        lastSync: DateTime.now().subtract(const Duration(minutes: 4)),
        firmwareVersion: '0.1.0-phase2',
        alcoholCalibrationAge: const Duration(days: 3),
      );
}
