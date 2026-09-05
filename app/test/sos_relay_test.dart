// Host tests for the SOS relay (01_REQUIREMENTS.md, 04_PHASES.md Phase 4).
// Every assertion maps to either "fail visibly, never silently" or
// "data + SMS are redundant channels, not a required pipeline"
// (03_RULES.md / 01_REQUIREMENTS.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helmet_app/logic/sos_relay.dart';
import 'package:smart_helmet_app/models/sos_dispatch.dart';
import 'package:smart_helmet_app/models/sos_event.dart';
import 'package:smart_helmet_app/services/location_provider.dart';
import 'package:smart_helmet_app/services/sos_transport.dart';

const _testEvent = SosEvent(
  type: SosTriggerType.crashImpact,
  severityScore: 84,
  confirmedBy: ['mpu6050', 'piezo'],
  timestampDeviceMs: 1234567,
);

SosRelay _relay({LocationProvider? location, SosTransport? transport}) => SosRelay(
      locationProvider: location ?? MockLocationProvider(delay: Duration.zero),
      transport: transport ?? MockSosTransport(delay: Duration.zero),
      driverName: 'Arjun',
      emergencyContactName: 'Priya',
      emergencyContactPhone: '+91-9000000000',
    );

void main() {
  test('both channels succeeding dispatches as sent, with a location', () async {
    final relay = _relay();
    final events = <SosDispatchRecord>[];
    relay.dispatches.listen(events.add);

    final result = await relay.dispatch(_testEvent);

    expect(result.status, SosDispatchStatus.sent);
    expect(result.anyChannelSucceeded, isTrue);
    expect(result.location, isNotNull);
    // locating -> sending -> sent, in order, never skipping a step.
    expect(events.map((e) => e.status).toList(), [
      SosDispatchStatus.locating,
      SosDispatchStatus.sending,
      SosDispatchStatus.sent,
    ]);
  });

  test('data channel down, SMS succeeds -> still sent (SMS is a real fallback)', () async {
    final relay = _relay(transport: MockSosTransport(dataChannelFails: true, delay: Duration.zero));
    final result = await relay.dispatch(_testEvent);
    expect(result.status, SosDispatchStatus.sent);
    expect(result.dataChannelResult!.ok, isFalse);
    expect(result.smsChannelResult!.ok, isTrue);
  });

  test('SMS down, data channel succeeds -> still sent', () async {
    final relay = _relay(transport: MockSosTransport(smsChannelFails: true, delay: Duration.zero));
    final result = await relay.dispatch(_testEvent);
    expect(result.status, SosDispatchStatus.sent);
  });

  test('both channels down -> failed, never silently dropped', () async {
    final relay = _relay(transport: MockSosTransport(dataChannelFails: true, smsChannelFails: true, delay: Duration.zero));
    final result = await relay.dispatch(_testEvent);
    expect(result.status, SosDispatchStatus.failed);
    expect(result.anyChannelSucceeded, isFalse);
  });

  test('a missing GPS fix does not block the dispatch', () async {
    final relay = _relay(location: MockLocationProvider(shouldFail: true, delay: Duration.zero));
    final result = await relay.dispatch(_testEvent);
    expect(result.location, isNull);
    expect(result.status, SosDispatchStatus.sent); // transport still ran
  });

  test('the payload reaching transport carries the driver, contact, and event', () async {
    final transport = MockSosTransport(delay: Duration.zero);
    final relay = _relay(transport: transport);
    await relay.dispatch(_testEvent);

    expect(transport.sentViaData, hasLength(1));
    final payload = transport.sentViaData.single;
    expect(payload.driverName, 'Arjun');
    expect(payload.emergencyContactName, 'Priya');
    expect(payload.emergencyContactPhone, '+91-9000000000');
    expect(payload.event.confirmedBy, ['mpu6050', 'piezo']);
  });
}
