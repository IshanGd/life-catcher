import 'dart:async';

import '../logic/fatigue_nudge_engine.dart';
import '../logic/ride_behavior_scorer.dart';
import '../models/device_health.dart';
import '../models/driver_event.dart';
import '../models/driver_profile.dart';
import '../models/helmet_status.dart';
import '../models/trend.dart';
import 'helmet_data_service.dart';

/// Sample data standing in for the real BLE pipeline (Phase 2 hardware) --
/// but the ride-behavior scoring and fatigue-nudge numbers it produces are
/// computed by the real [RideBehaviorScorer] / [FatigueNudgeEngine] logic,
/// not hardcoded. Only the inputs (per-day harsh-event rates, a simulated
/// continuous-riding clock) are sample data; what happens to them is real.
///
/// This is the "mockup with sample data" 04_PHASES.md Phase 0 describes --
/// it never existed as a committed mockup in this repo, so this class is
/// that starting point, built directly against the real
/// [HelmetDataService] seam instead of a throwaway prototype.
class MockHelmetDataService implements HelmetDataService {
  MockHelmetDataService()
      : _shiftStart = DateTime.now().subtract(const Duration(hours: 2, minutes: 14)),
        _fatigueEngine = FatigueNudgeEngine(continuousSince: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)));

  final DateTime _shiftStart;
  final FatigueNudgeEngine _fatigueEngine;

  /// Nudges the fatigue engine has actually fired, newest first -- merged
  /// into the event history so a live-fired nudge shows up for real, not
  /// just as a canned historical row.
  final List<DriverEvent> _firedNudgeEvents = [];
  int _nudgeIdCounter = 0;

  /// Per-day harsh-event rates for the week (Mon..Sun, Sun == today) --
  /// the simulated stand-in for real accel+GPS-derived telemetry
  /// (01_REQUIREMENTS.md §4.4). [RideBehaviorScorer] turns these into the
  /// actual scores shown in the UI; nothing below is a pre-computed score.
  static const _weeklyRideInputs = <String, RideBehaviorInput>{
    'Mon': RideBehaviorInput(harshBrakingPer100km: 3.6, harshAccelPer100km: 2.8, corneringPer100km: 1.8),
    'Tue': RideBehaviorInput(harshBrakingPer100km: 3.0, harshAccelPer100km: 2.2, corneringPer100km: 1.5),
    'Wed': RideBehaviorInput(harshBrakingPer100km: 3.8, harshAccelPer100km: 3.0, corneringPer100km: 2.0),
    'Thu': RideBehaviorInput(harshBrakingPer100km: 2.6, harshAccelPer100km: 2.0, corneringPer100km: 1.2),
    'Fri': RideBehaviorInput(harshBrakingPer100km: 2.4, harshAccelPer100km: 1.8, corneringPer100km: 1.0),
    'Sat': RideBehaviorInput(harshBrakingPer100km: 2.2, harshAccelPer100km: 1.6, corneringPer100km: 0.8),
    'Sun': RideBehaviorInput(harshBrakingPer100km: 2.1, harshAccelPer100km: 1.4, corneringPer100km: 0.6),
  };

  List<TrendPoint> _weeklyScores() => [
        for (final entry in _weeklyRideInputs.entries) TrendPoint(label: entry.key, score: RideBehaviorScorer.score(entry.value)),
      ];

  @override
  Stream<HelmetStatus> watchStatus() async* {
    yield _statusNow();
    yield* Stream.periodic(const Duration(seconds: 1), (_) => _statusNow());
  }

  HelmetStatus _statusNow() {
    final now = DateTime.now();
    _fatigueEngine.tick(now);
    var nudge = _fatigueEngine.popNudge();
    while (nudge != null) {
      _firedNudgeEvents.insert(
        0,
        DriverEvent(
          id: 'nudge-${_nudgeIdCounter++}',
          kind: EventKind.fatigueNudgeSent,
          timestamp: nudge.firedAt,
          description: 'Fatigue nudge sent — ${_formatHours(nudge.continuousDuration)} continuous riding',
        ),
      );
      nudge = _fatigueEngine.popNudge();
    }

    final scores = _weeklyScores();
    final today = scores.last.score;
    final yesterday = scores[scores.length - 2].score;
    final firstHalfAvg = _average(scores.take(scores.length ~/ 2).map((p) => p.score));
    final secondHalfAvg = _average(scores.skip(scores.length ~/ 2).map((p) => p.score));

    return HelmetStatus(
      driverName: 'Arjun',
      platformName: 'Rapido',
      shiftDuration: now.difference(_shiftStart),
      helmetWorn: true,
      preRide: PreRideStatus.passed,
      bleConnected: true,
      batteryPct: 78,
      firmwareVersion: '0.1.0-phase2',
      safetyScoreToday: today,
      safetyScoreDeltaVsYesterday: today - yesterday,
      riskTrend7dScore: _average(scores.map((p) => p.score)).round(),
      riskTrendImproving: secondHalfAvg >= firstHalfAvg,
      continuousShiftDuration: _fatigueEngine.continuousDuration(now),
      breakSuggestedIn: _fatigueEngine.breakSuggestedIn(now),
    );
  }

  static double _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static String _formatHours(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h${m > 0 ? ' ${m}m' : ''}' : '${m}m';
  }

  @override
  Future<List<DriverEvent>> recentEvents({int limit = 3}) async {
    final all = await alertHistory();
    return all.take(limit).toList();
  }

  @override
  Future<List<DriverEvent>> alertHistory() async {
    final now = DateTime.now();
    final canned = [
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
    return [..._firedNudgeEvents, ...canned];
  }

  @override
  Future<List<TrendPoint>> weeklyTrend() async => _weeklyScores();

  @override
  Future<List<HarshEventRate>> harshEventBreakdown() async {
    final today = _weeklyRideInputs['Sun']!;
    return [
      HarshEventRate(label: 'Harsh braking', ratePer100km: today.harshBrakingPer100km),
      HarshEventRate(label: 'Harsh acceleration', ratePer100km: today.harshAccelPer100km),
      HarshEventRate(label: 'Cornering anomalies', ratePer100km: today.corneringPer100km),
    ];
  }

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
