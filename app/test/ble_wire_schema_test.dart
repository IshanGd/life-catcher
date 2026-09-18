// Wire-contract tests -- no BLE hardware or platform channels involved.
// Every JSON literal below is shaped exactly like firmware/src/core/
// ble_schema.cpp's real Serialize() output (see that file, and the boot
// logs captured live from real hardware this session), not guessed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helmet_app/services/ble/ble_wire_schema.dart';

void main() {
  group('BleStatusPayload', () {
    test('parses a normal status notification', () {
      const json = '{"schema":1,"helmet_worn":true,"pre_ride_passed":false,'
          '"battery_pct":78,"firmware":"0.1.0-phase2","ble_link":true,"event":null}';
      final p = BleStatusPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(p.schema, 1);
      expect(p.helmetWorn, isTrue);
      expect(p.preRidePassed, isFalse);
      expect(p.batteryPct, 78);
      expect(p.firmware, '0.1.0-phase2');
      expect(p.bleLink, isTrue);
    });

    test('battery_pct null means unknown, matching the firmware -1 sentinel', () {
      const json = '{"schema":1,"helmet_worn":false,"pre_ride_passed":false,'
          '"battery_pct":null,"firmware":"0.1.0-phase2","ble_link":true,"event":null}';
      final p = BleStatusPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(p.batteryPct, isNull);
    });

    test('tryDecode returns null on malformed bytes instead of throwing', () {
      expect(BleStatusPayload.tryDecode(utf8.encode('not json')), isNull);
      expect(BleStatusPayload.tryDecode(const [0xFF, 0x00, 0x12]), isNull);
    });
  });

  group('BleEventPayload', () {
    test('parses a fresh crash_impact, fusion-confirmed by two sources', () {
      const json = '{"schema":1,"event_type":"crash_impact","severity_score":84,'
          '"confirmed_by":["mpu6050","piezo"],"timestamp_device_ms":1234567,'
          '"awaiting_cancel":true,"cancel_window_sec":10,"cancelled":false,"confirmed":false}';
      final e = BleEventPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(e.eventType, 'crash_impact');
      expect(e.severityScore, 84);
      expect(e.confirmedBy, ['mpu6050', 'piezo']);
      expect(e.timestampDeviceMs, 1234567);
      expect(e.awaitingCancel, isTrue);
      expect(e.cancelWindowSec, 10);
      expect(e.cancelled, isFalse);
      expect(e.confirmed, isFalse);
      expect(e.cancelReason, isNull);
    });

    test('parses the cancelled follow-up notification, reason included', () {
      const json = '{"schema":1,"event_type":"crash_impact","severity_score":84,'
          '"confirmed_by":["mpu6050","piezo"],"timestamp_device_ms":1234567,'
          '"awaiting_cancel":false,"cancel_window_sec":10,"cancelled":true,'
          '"confirmed":false,"cancel_reason":"driver"}';
      final e = BleEventPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(e.cancelled, isTrue);
      expect(e.confirmed, isFalse);
      expect(e.cancelReason, 'driver');
    });

    test('parses the confirmed follow-up notification -- this is what triggers the SOS relay', () {
      const json = '{"schema":1,"event_type":"crash_impact","severity_score":84,'
          '"confirmed_by":["mpu6050","piezo"],"timestamp_device_ms":1234567,'
          '"awaiting_cancel":false,"cancel_window_sec":10,"cancelled":false,"confirmed":true}';
      final e = BleEventPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(e.awaitingCancel, isFalse);
      expect(e.confirmed, isTrue);
    });

    test('parses a single-sensor alcohol_flag (ADR-5: gate, not fusion-confirmed)', () {
      const json = '{"schema":1,"event_type":"alcohol_flag","severity_score":0,'
          '"confirmed_by":["mq3"],"timestamp_device_ms":999,'
          '"awaiting_cancel":false,"cancel_window_sec":0,"cancelled":false,"confirmed":false}';
      final e = BleEventPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(e.confirmedBy, ['mq3']);
      expect(e.confirmed, isFalse);
    });

    test('parses a non-emergency ride event (no lifecycle follow-up)', () {
      const json = '{"schema":1,"event_type":"harsh_brake","severity_score":40,'
          '"confirmed_by":[],"timestamp_device_ms":42,'
          '"awaiting_cancel":false,"cancel_window_sec":0,"cancelled":false,"confirmed":false}';
      final e = BleEventPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(e.eventType, 'harsh_brake');
      expect(e.confirmedBy, isEmpty);
    });
  });

  group('BleCommands', () {
    // Exact bytes firmware/tools/ble_probe.py already proves the firmware
    // accepts (GattServer::OnCommandWrite's substring match).
    test('cancel/ack/start_check match the known-working wire format', () {
      expect(utf8.decode(BleCommands.cancel), '{"cmd":"cancel"}');
      expect(utf8.decode(BleCommands.ack), '{"cmd":"ack"}');
      expect(utf8.decode(BleCommands.startCheck), '{"cmd":"start_check"}');
    });
  });
}
