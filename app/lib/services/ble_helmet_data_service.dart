import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../logic/fatigue_nudge_engine.dart';
import '../logic/ride_behavior_scorer.dart';
import '../models/device_health.dart';
import '../models/driver_event.dart';
import '../models/driver_profile.dart';
import '../models/helmet_status.dart';
import '../models/sos_event.dart';
import '../models/trend.dart';
import 'ble/ble_wire_schema.dart';
import 'helmet_data_service.dart';
import 'local_event_store.dart';

/// Real BLE-backed [HelmetDataService] -- talks to the firmware's NimBLE
/// GATT server (`firmware/src/ble/gatt_server.cpp`, wire contract in
/// `firmware/src/core/ble_schema.h`) the same way
/// `firmware/tools/ble_probe.py` already proves works. 02_ARCHITECTURE.md
/// §5: this is the only file that should ever need to change to swap the
/// data source in `main.dart` -- no screen references BLE directly.
///
/// Requires Android's BLUETOOTH_SCAN/BLUETOOTH_CONNECT (+ location on old
/// Android) and iOS's NSBluetoothAlwaysUsageDescription to actually run on
/// a phone -- added once `android/`/`ios/` platform folders exist (they
/// don't in this repo yet; see the plan this was built from).
///
/// Honesty notes on 3 methods that have no real signal from the firmware
/// yet, so screens reading them should know what they're looking at:
/// - [harshEventBreakdown]: the firmware's `EventType` enum
///   (`ble_schema.h`) only distinguishes `harsh_brake` from everything
///   else -- there's no separate "harsh acceleration" or "cornering"
///   event. Those two categories report a real, not fabricated, `0`
///   (nothing of that kind has ever been observed, because nothing of
///   that kind is ever sent), not an estimate.
/// - [weeklyTrend] / [harshEventBreakdown]: counts of real events per day
///   feed `RideBehaviorScorer` directly, standing in for the true
///   per-100km rate the model expects -- there's no distance/GPS
///   integration in this pass to normalize by. Re-visit once ride
///   distance is tracked.
/// - [complianceStats].helmetWearRatePct defaults to 100 before any time
///   has been observed (a fresh install), rather than reading as 0% worn
///   when the truth is "no data yet."
class BleHelmetDataService implements HelmetDataService {
  BleHelmetDataService() {
    unawaited(_init());
  }

  static const _deviceNamePrefix = 'SmartHelmet';

  late final LocalEventStore _store;
  final _statusController = StreamController<HelmetStatus>.broadcast();
  final _sosEventController = StreamController<SosEvent>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _eventChar;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _statusNotifySub;
  StreamSubscription<List<int>>? _eventNotifySub;
  Timer? _tickTimer;

  bool _connected = false;
  BleStatusPayload? _lastStatus;
  DateTime? _lastNotifyAt;
  FatigueNudgeEngine? _fatigueEngine;
  bool? _lastWorn;
  bool _lastPreRidePassed = false;
  bool _preRideFailed = false; // set by a real alcohol_flag event (ADR-5), not guessed

  Future<void> _init() async {
    _store = await LocalEventStore.open();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_scanAndConnect());
  }

  void dispose() {
    _tickTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    _statusNotifySub?.cancel();
    _eventNotifySub?.cancel();
    _statusController.close();
    _sosEventController.close();
  }

  // --- connection lifecycle ------------------------------------------------

  Future<void> _scanAndConnect() async {
    try {
      final found = Completer<BluetoothDevice?>();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.advertisementData.advName.startsWith(_deviceNamePrefix) && !found.isCompleted) {
            found.complete(r.device);
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      final device = await found.future.timeout(const Duration(seconds: 16), onTimeout: () => null);
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      if (device == null) {
        // No helmet in range yet -- keep trying rather than give up.
        Timer(const Duration(seconds: 5), () => unawaited(_scanAndConnect()));
        return;
      }
      await _connect(device);
    } catch (_) {
      Timer(const Duration(seconds: 5), () => unawaited(_scanAndConnect()));
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    _connSub = device.connectionState.listen(_onConnectionStateChange);
    // autoConnect: the firmware resumes advertising on its own disconnect
    // (ServerCb::onDisconnect, gatt_server.cpp) -- the phone side should
    // keep retrying too instead of surfacing a dead link.
    // license: nonprofit -- Life Catcher is a personal/nonprofit project,
    // not commercial use, per flutter_blue_plus's licensing terms.
    // mtu: null -- requesting a larger MTU inline here, combined with
    // autoConnect: true, hangs the connect on Android (silently retried
    // forever by _scanAndConnect's catch-and-retry). Request it separately
    // once actually connected instead -- see _onConnectionStateChange.
    await device.connect(license: License.nonprofit, autoConnect: true, mtu: null);
  }

  Future<void> _onConnectionStateChange(BluetoothConnectionState state) async {
    _connected = state == BluetoothConnectionState.connected;
    if (_connected) {
      // EventPayload/StatusPayload JSON runs well past the default 23-byte
      // ATT MTU; without this, notifications silently truncate and
      // BleEventPayload.tryDecode() drops them with no trace. iOS negotiates
      // its own MTU automatically and throws if asked explicitly, hence the
      // platform guard. Failure here shouldn't block the connection itself --
      // worst case we stay at the default MTU, which is recoverable, whereas
      // a stuck connect() is not.
      if (Platform.isAndroid) {
        try {
          await _device?.requestMtu(512);
        } catch (e) {
          debugPrint('[BLE] requestMtu failed, staying at default MTU: $e');
        }
      }
      await _subscribeCharacteristics();
    } else {
      await _statusNotifySub?.cancel();
      await _eventNotifySub?.cancel();
    }
    _emitStatus();
  }

  Future<void> _subscribeCharacteristics() async {
    final device = _device;
    if (device == null) return;
    try {
      final services = await device.discoverServices();
      final svc = services.firstWhere((s) => s.uuid.toString().toLowerCase() == BleUuids.service);
      _statusChar = svc.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == BleUuids.status);
      _eventChar = svc.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == BleUuids.event);
      _cmdChar = svc.characteristics.firstWhere((c) => c.uuid.toString().toLowerCase() == BleUuids.command);

      await _statusChar!.setNotifyValue(true);
      _statusNotifySub = _statusChar!.onValueReceived.listen(_onStatusBytes);
      await _eventChar!.setNotifyValue(true);
      _eventNotifySub = _eventChar!.onValueReceived.listen(_onEventBytes);

      // Don't wait for the firmware's next periodic PublishStatus() --
      // read what's already latched on the characteristic right now.
      _onStatusBytes(await _statusChar!.read());
      debugPrint('[BLE] subscribed to status + event characteristics OK');
    } catch (e) {
      // Discovery raced a reconnect, or the GATT service isn't up yet --
      // the next connectionState transition retries this. Logged because a
      // *persistent* failure here (bad UUID, missing characteristic) would
      // otherwise look identical to "notifications never arrive" with zero
      // trace of why.
      debugPrint('[BLE] _subscribeCharacteristics failed: $e');
    }
  }

  // --- command writes (not part of HelmetDataService -- no screen calls
  // these yet; wiring a "start pre-ride check" UI action is a follow-up) --

  Future<void> sendCancel() => _writeCommand(BleCommands.cancel);
  Future<void> sendAck() => _writeCommand(BleCommands.ack);
  Future<void> sendStartPreRideCheck() => _writeCommand(BleCommands.startCheck);

  Future<void> _writeCommand(List<int> bytes) async {
    final cmd = _cmdChar;
    if (cmd == null) return;
    await cmd.write(bytes, withoutResponse: false);
  }

  // --- incoming notifications ----------------------------------------------

  void _onStatusBytes(List<int> bytes) {
    final payload = BleStatusPayload.tryDecode(bytes);
    if (payload == null) return;
    _lastStatus = payload;
    _lastNotifyAt = DateTime.now();

    // Real transitions, not a simulated clock -- drives the fatigue engine
    // and the pre-ride-check compliance counters from what the helmet
    // actually reported.
    if (payload.helmetWorn && _lastWorn != true) {
      _fatigueEngine = FatigueNudgeEngine(continuousSince: DateTime.now());
      _preRideFailed = false; // a fresh donning starts a fresh pre-ride cycle
    } else if (!payload.helmetWorn && _lastWorn == true) {
      _fatigueEngine = null;
    }
    _lastWorn = payload.helmetWorn;

    if (payload.preRidePassed && !_lastPreRidePassed) {
      _preRideFailed = false;
      unawaited(_logPreRideCheckPassed());
    }
    _lastPreRidePassed = payload.preRidePassed;

    _emitStatus();
  }

  Future<void> _logPreRideCheckPassed() async {
    await _store.incrementCounter('prc_completed');
    await _store.incrementCounter('prc_total');
    await _store.addEvent(DriverEvent(
      id: 'prc-${DateTime.now().millisecondsSinceEpoch}',
      kind: EventKind.preRideCheckPassed,
      timestamp: DateTime.now(),
      description: 'Pre-ride check passed',
    ));
  }

  void _onEventBytes(List<int> bytes) {
    final payload = BleEventPayload.tryDecode(bytes);
    if (payload == null) return;
    _lastNotifyAt = DateTime.now();
    unawaited(_handleEvent(payload));
  }

  Future<void> _handleEvent(BleEventPayload e) async {
    final kind = _eventKindFor(e.eventType);
    if (kind == EventKind.alcoholFlag) {
      _preRideFailed = true; // real ADR-5 gate signal, surfaced in _emitStatus
      await _store.incrementCounter('prc_total'); // observed, and it failed
    }

    await _store.addEvent(DriverEvent(
      id: 'evt-${e.timestampDeviceMs}',
      kind: kind,
      timestamp: DateTime.now(),
      description: _describeEvent(e),
      cancelled: e.cancelled,
      cancelReason: e.cancelReason,
    ));

    // ADR-4: only a fusion-confirmed, non-cancelled crash/panic event goes
    // to the SOS relay. Everything else -- ride-scoring events, a
    // cancelled or still-awaiting one -- stops at the event log above.
    final isSosType = e.eventType == 'crash_impact' || e.eventType == 'panic_button';
    if (isSosType && e.confirmed) {
      _sosEventController.add(SosEvent(
        type: e.eventType == 'crash_impact' ? SosTriggerType.crashImpact : SosTriggerType.panicButton,
        severityScore: e.severityScore,
        confirmedBy: e.confirmedBy,
        timestampDeviceMs: e.timestampDeviceMs,
      ));
    }
    _emitStatus();
  }

  static EventKind _eventKindFor(String wire) {
    switch (wire) {
      case 'normal_riding':
        return EventKind.normalRiding;
      case 'pothole_bump':
        return EventKind.potholeBump;
      case 'harsh_brake':
        return EventKind.harshBrake;
      case 'crash_impact':
        return EventKind.crashImpact;
      case 'panic_button':
        return EventKind.panicButton;
      case 'alcohol_flag':
        return EventKind.alcoholFlag;
      default:
        return EventKind.normalRiding;
    }
  }

  static String _describeEvent(BleEventPayload e) {
    if (e.cancelled) return '${_titleFor(e.eventType)} — cancelled by driver';
    if (e.confirmed) return '${_titleFor(e.eventType)} — confirmed';
    return _titleFor(e.eventType);
  }

  static String _titleFor(String wire) {
    switch (wire) {
      case 'crash_impact':
        return 'Impact alert';
      case 'panic_button':
        return 'Panic button SOS';
      case 'harsh_brake':
        return 'Harsh braking detected';
      case 'pothole_bump':
        return 'Pothole/bump detected';
      case 'alcohol_flag':
        return 'Pre-ride alcohol check flagged';
      default:
        return 'Ride event';
    }
  }

  // --- status ticking / scoring --------------------------------------------

  void _tick() {
    if (_connected && _lastStatus != null) {
      unawaited(_store.incrementCounter('observed_seconds'));
      if (_lastStatus!.helmetWorn) unawaited(_store.incrementCounter('worn_seconds'));
    }
    _emitStatus();
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    final now = DateTime.now();
    final status = _lastStatus;
    final profile = _store.loadProfile();
    final fatigue = _fatigueEngine;

    if (fatigue != null) {
      fatigue.tick(now);
      var nudge = fatigue.popNudge();
      while (nudge != null) {
        unawaited(_store.addEvent(DriverEvent(
          id: 'nudge-${now.microsecondsSinceEpoch}',
          kind: EventKind.fatigueNudgeSent,
          timestamp: nudge.firedAt,
          description: 'Fatigue nudge sent — continuous riding',
        )));
        nudge = fatigue.popNudge();
      }
    }

    final scores = _recentDailyScores();
    final today = scores.isNotEmpty ? scores.last.score : 100;
    final yesterday = scores.length >= 2 ? scores[scores.length - 2].score : today;
    // No independent "shift start" signal exists yet (only continuous-wear
    // streaks do) -- both durations track the same fatigue-engine clock
    // until a real shift-boundary concept exists.
    final continuous = fatigue?.continuousDuration(now) ?? Duration.zero;

    _statusController.add(HelmetStatus(
      driverName: profile.name,
      platformName: profile.platform,
      shiftDuration: continuous,
      helmetWorn: status?.helmetWorn ?? false,
      preRide: status == null
          ? PreRideStatus.pending
          : (status.preRidePassed ? PreRideStatus.passed : (_preRideFailed ? PreRideStatus.failed : PreRideStatus.pending)),
      bleConnected: _connected,
      batteryPct: status?.batteryPct,
      firmwareVersion: status?.firmware ?? '—',
      safetyScoreToday: today,
      safetyScoreDeltaVsYesterday: today - yesterday,
      riskTrend7dScore: scores.isEmpty ? 100 : _avg(scores.map((p) => p.score)).round(),
      riskTrendImproving: _trendImproving(scores),
      continuousShiftDuration: continuous,
      breakSuggestedIn: fatigue?.breakSuggestedIn(now) ?? FatigueNudgeEngine.kBreakSuggestionThreshold,
    ));
  }

  List<TrendPoint> _recentDailyScores() {
    final events = _store.loadEvents();
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final days = List.generate(7, (i) => startOfToday.subtract(Duration(days: 6 - i)));
    return [for (final day in days) TrendPoint(label: _weekdayLabel(day), score: RideBehaviorScorer.score(_dailyInput(events, day)))];
  }

  static RideBehaviorInput _dailyInput(List<DriverEvent> events, DateTime day) {
    bool sameDay(DriverEvent e) => e.timestamp.year == day.year && e.timestamp.month == day.month && e.timestamp.day == day.day;
    final harshBrakes = events.where((e) => sameDay(e) && e.kind == EventKind.harshBrake && !e.cancelled).length;
    // See the class doc: the firmware has no distinct harsh-acceleration or
    // cornering signal, so these are real zeros, not fabricated estimates.
    return RideBehaviorInput(
      harshBrakingPer100km: harshBrakes.toDouble(),
      harshAccelPer100km: 0,
      corneringPer100km: 0,
    );
  }

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String _weekdayLabel(DateTime d) => _weekdayLabels[d.weekday - 1];

  static bool _trendImproving(List<TrendPoint> scores) {
    if (scores.length < 2) return true;
    final firstHalf = _avg(scores.take(scores.length ~/ 2).map((p) => p.score));
    final secondHalf = _avg(scores.skip(scores.length ~/ 2).map((p) => p.score));
    return secondHalf >= firstHalf;
  }

  static double _avg(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  // --- HelmetDataService -----------------------------------------------

  @override
  Stream<HelmetStatus> watchStatus() => _statusController.stream;

  @override
  Future<List<DriverEvent>> recentEvents({int limit = 3}) async => _store.loadEvents().take(limit).toList();

  @override
  Future<List<DriverEvent>> alertHistory() async => _store.loadEvents();

  @override
  Future<List<TrendPoint>> weeklyTrend() async => _recentDailyScores();

  @override
  Future<List<HarshEventRate>> harshEventBreakdown() async {
    final today = DateTime.now();
    final input = _dailyInput(_store.loadEvents(), DateTime(today.year, today.month, today.day));
    return [
      HarshEventRate(label: 'Harsh braking', ratePer100km: input.harshBrakingPer100km),
      HarshEventRate(label: 'Harsh acceleration', ratePer100km: input.harshAccelPer100km),
      HarshEventRate(label: 'Cornering anomalies', ratePer100km: input.corneringPer100km),
    ];
  }

  @override
  Future<ComplianceStats> complianceStats() async {
    final observed = _store.getCounter('observed_seconds');
    final worn = _store.getCounter('worn_seconds');
    final completed = _store.getCounter('prc_completed');
    final total = _store.getCounter('prc_total');
    return ComplianceStats(
      helmetWearRatePct: observed == 0 ? 100 : ((worn / observed) * 100).round().clamp(0, 100).toInt(),
      preRideChecksCompleted: completed,
      preRideChecksTotal: total < completed ? completed : total,
    );
  }

  @override
  Future<DriverProfile> driverProfile() async => _store.loadProfile();

  @override
  Future<DeviceHealth> deviceHealth() async {
    final status = _lastStatus;
    return DeviceHealth(
      batteryPct: status?.batteryPct,
      lastSync: _lastNotifyAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      firmwareVersion: status?.firmware ?? '—',
      // No calibration-timestamp field exists on the wire yet
      // (ble_schema.h's StatusPayload/EventPayload) -- null is the model's
      // own "not calibrated yet" state, not a guess.
      alcoholCalibrationAge: null,
    );
  }

  @override
  Stream<SosEvent> watchConfirmedSosEvents() => _sosEventController.stream;

  @override
  void recordSosDispatchOutcome(DriverEvent event) => unawaited(_store.addEvent(event));
}
