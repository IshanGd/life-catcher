import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

/// The BLE wire contract, mirrored field-for-field from the firmware's
/// `firmware/src/core/ble_schema.h` / `.cpp` (Serialize()). Kept separate
/// from any BLE plumbing so it's unit-testable with plain JSON strings and
/// no hardware -- see `app/test/ble_wire_schema_test.dart`.
///
/// UUIDs match `firmware/src/ble/gatt_server.cpp` and
/// `firmware/tools/ble_probe.py` exactly.
class BleUuids {
  BleUuids._();

  static const service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const status = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const event = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const command = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
}

/// Mirrors `helmet::schema::StatusPayload`.
class BleStatusPayload {
  const BleStatusPayload({
    required this.schema,
    required this.helmetWorn,
    required this.preRidePassed,
    required this.batteryPct,
    required this.firmware,
    required this.bleLink,
  });

  final int schema;
  final bool helmetWorn;
  final bool preRidePassed;
  final int? batteryPct; // null == unknown, matches the firmware's -1 sentinel
  final String firmware;
  final bool bleLink;

  static BleStatusPayload fromJson(Map<String, dynamic> json) => BleStatusPayload(
        schema: json['schema'] as int,
        helmetWorn: json['helmet_worn'] as bool,
        preRidePassed: json['pre_ride_passed'] as bool,
        batteryPct: json['battery_pct'] as int?,
        firmware: json['firmware'] as String,
        bleLink: json['ble_link'] as bool,
      );

  static BleStatusPayload? tryDecode(List<int> bytes) {
    try {
      return fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (e) {
      // Malformed/partial notification -- caller keeps the last-known value.
      // A truncated payload here almost always means the ATT MTU is too
      // small for this JSON (see BleHelmetDataService._connect's mtu: 512).
      debugPrint('[BLE] StatusPayload decode failed (${bytes.length}B): $e');
      return null;
    }
  }
}

/// Mirrors `helmet::schema::EventPayload`. `eventType` stays the raw wire
/// string (e.g. "crash_impact") -- mapping to the app's `EventKind` /
/// `SosTriggerType` enums happens in `BleHelmetDataService`, not here, so
/// this file has no dependency on app models.
class BleEventPayload {
  const BleEventPayload({
    required this.schema,
    required this.eventType,
    required this.severityScore,
    required this.confirmedBy,
    required this.timestampDeviceMs,
    required this.awaitingCancel,
    required this.cancelWindowSec,
    required this.cancelled,
    required this.confirmed,
    this.cancelReason,
  });

  final int schema;
  final String eventType;
  final int severityScore;
  final List<String> confirmedBy; // e.g. ["mpu6050", "piezo"]
  final int timestampDeviceMs;
  final bool awaitingCancel;
  final int cancelWindowSec;
  final bool cancelled;
  final bool confirmed;
  final String? cancelReason; // absent on the wire unless non-empty

  static BleEventPayload fromJson(Map<String, dynamic> json) => BleEventPayload(
        schema: json['schema'] as int,
        eventType: json['event_type'] as String,
        severityScore: json['severity_score'] as int,
        confirmedBy: (json['confirmed_by'] as List<dynamic>? ?? const []).cast<String>(),
        timestampDeviceMs: json['timestamp_device_ms'] as int,
        awaitingCancel: json['awaiting_cancel'] as bool,
        cancelWindowSec: json['cancel_window_sec'] as int,
        cancelled: json['cancelled'] as bool,
        confirmed: json['confirmed'] as bool,
        cancelReason: json['cancel_reason'] as String?,
      );

  static BleEventPayload? tryDecode(List<int> bytes) {
    try {
      return fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[BLE] EventPayload decode failed (${bytes.length}B): $e');
      return null;
    }
  }
}

/// The 3 writes `ble_probe.py` already proves the firmware accepts
/// (`GattServer::OnCommandWrite`'s substring match on `"cancel"` / `"ack"` /
/// `"start_check"`).
class BleCommands {
  BleCommands._();

  static final cancel = utf8.encode('{"cmd":"cancel"}');
  static final ack = utf8.encode('{"cmd":"ack"}');
  static final startCheck = utf8.encode('{"cmd":"start_check"}');
}
