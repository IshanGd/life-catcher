import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_event.dart';
import '../models/driver_profile.dart';

/// On-device persistence for [BleHelmetDataService] -- separate from any BLE
/// concern, same single-purpose-file granularity as `location_provider.dart`
/// / `sos_transport.dart`. Everything here is real, locally-accumulated
/// data: the event log only ever grows from live EVENT notifications the
/// helmet actually sent, never sample/canned rows.
class LocalEventStore {
  LocalEventStore._(this._prefs);

  static const _eventsKey = 'helmet.event_log.v1';
  static const _profileKey = 'helmet.driver_profile.v1';

  // Caps the persisted log so a long-running install doesn't grow it
  // unbounded; plenty for the Alerts tab's audit trail and the 7-day trend
  // window this feeds.
  static const _maxEvents = 500;

  final SharedPreferences _prefs;

  static Future<LocalEventStore> open() async => LocalEventStore._(await SharedPreferences.getInstance());

  List<DriverEvent> loadEvents() {
    final raw = _prefs.getString(_eventsKey);
    // Growable, not const -- addEvent() inserts into whatever this returns,
    // and a const [] throws on the very first event on a fresh install
    // (Unsupported operation: Cannot add to an unmodifiable list).
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(_eventFromJson).toList();
  }

  /// Newest-first, matching every screen's expectation
  /// (`MockHelmetDataService.alertHistory`'s ordering).
  Future<void> addEvent(DriverEvent event) async {
    final events = loadEvents()..insert(0, event);
    if (events.length > _maxEvents) events.removeRange(_maxEvents, events.length);
    await _prefs.setString(_eventsKey, jsonEncode(events.map(_eventToJson).toList()));
  }

  DriverProfile loadProfile() {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return _defaultProfile;
    return _profileFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(DriverProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(_profileToJson(profile)));
  }

  // Small persisted counters `BleHelmetDataService` uses to build
  // `ComplianceStats` from real observed time/events instead of a canned
  // number -- e.g. `observed_seconds`/`worn_seconds` for helmet-wear rate,
  // `prc_completed`/`prc_total` for pre-ride-check compliance.
  int getCounter(String key) => _prefs.getInt('helmet.counter.$key') ?? 0;

  Future<void> incrementCounter(String key, [int by = 1]) =>
      _prefs.setInt('helmet.counter.$key', getCounter(key) + by);

  // No profile-editing screen exists yet (a follow-up task, not part of
  // wiring up real BLE) -- these are honest placeholders, not fabricated
  // driver data. `deviceId` matches the name the firmware actually
  // advertises (`GattServer::Begin` in `firmware/src/ble/gatt_server.cpp`).
  static const _defaultProfile = DriverProfile(
    name: 'Driver',
    avatarInitials: 'DR',
    platform: 'Not set',
    vehicleType: 'Two-wheeler',
    deviceId: 'SmartHelmet-0001',
    pairingStatus: PairingStatus.unpaired,
  );

  static Map<String, dynamic> _eventToJson(DriverEvent e) => {
        'id': e.id,
        'kind': e.kind.name,
        'timestamp': e.timestamp.toIso8601String(),
        'description': e.description,
        'location': e.location,
        'cancelled': e.cancelled,
        'cancel_reason': e.cancelReason,
      };

  static DriverEvent _eventFromJson(Map<String, dynamic> j) => DriverEvent(
        id: j['id'] as String,
        kind: EventKind.values.byName(j['kind'] as String),
        timestamp: DateTime.parse(j['timestamp'] as String),
        description: j['description'] as String,
        location: j['location'] as String?,
        cancelled: j['cancelled'] as bool? ?? false,
        cancelReason: j['cancel_reason'] as String?,
      );

  static Map<String, dynamic> _profileToJson(DriverProfile p) => {
        'name': p.name,
        'avatar_initials': p.avatarInitials,
        'platform': p.platform,
        'vehicle_type': p.vehicleType,
        'device_id': p.deviceId,
        'pairing_status': p.pairingStatus.name,
        'emergency_contact_name': p.emergencyContactName,
        'emergency_contact_phone': p.emergencyContactPhone,
      };

  static DriverProfile _profileFromJson(Map<String, dynamic> j) => DriverProfile(
        name: j['name'] as String,
        avatarInitials: j['avatar_initials'] as String,
        platform: j['platform'] as String,
        vehicleType: j['vehicle_type'] as String,
        deviceId: j['device_id'] as String,
        pairingStatus: PairingStatus.values.byName(j['pairing_status'] as String),
        emergencyContactName: j['emergency_contact_name'] as String?,
        emergencyContactPhone: j['emergency_contact_phone'] as String?,
      );
}
