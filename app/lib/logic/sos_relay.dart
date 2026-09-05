import 'dart:async';

import '../models/geo_location.dart';
import '../models/sos_dispatch.dart';
import '../models/sos_event.dart';
import '../services/location_provider.dart';
import '../services/sos_transport.dart';

/// SOS relay via phone data/SMS + GPS (01_REQUIREMENTS.md; 04_PHASES.md
/// Phase 4's last item). ADR-1: the helmet has no cellular/GPS of its own
/// by design -- once a fusion-confirmed, non-cancelled SOS reaches the
/// phone, dispatching it is entirely this class's job.
///
/// Depends only on the [LocationProvider] / [SosTransport] interfaces, not
/// their mock implementations, so a real GPS/SMS backend drops in later
/// without this class changing -- same seam discipline as
/// [HelmetDataService].
///
/// 03_RULES.md "fail visibly, not silently" applies to the dispatch itself:
/// every call to [dispatch] emits locating -> sending -> sent/failed on
/// [dispatches], never a silent gap, and a missing GPS fix does not block
/// the alert from going out (better a late/no-location SOS than none).
class SosRelay {
  SosRelay({
    required this.locationProvider,
    required this.transport,
    required this.driverName,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  final LocationProvider locationProvider;
  final SosTransport transport;
  final String driverName;
  final String emergencyContactName;
  final String emergencyContactPhone;

  // sync: true -- each status transition (locating/sending/sent/failed)
  // must reach listeners immediately, not on a later microtask, so a
  // caller that awaits dispatch() and then reads the last-known status
  // (e.g. a test, or a widget rebuilding off this stream) never observes a
  // stale state.
  final _controller = StreamController<SosDispatchRecord>.broadcast(sync: true);
  Stream<SosDispatchRecord> get dispatches => _controller.stream;

  /// Call for every SOS that finishes fusion-confirmed and non-cancelled
  /// (never for a cancelled one -- that path stops at the event log, see
  /// 02_ARCHITECTURE.md §4). Never throws; failures surface as a `failed`
  /// [SosDispatchRecord], not an exception.
  Future<SosDispatchRecord> dispatch(SosEvent event) async {
    _emit(SosDispatchRecord(event: event, status: SosDispatchStatus.locating));

    GeoLocation? location;
    try {
      location = await locationProvider.currentLocation();
    } catch (_) {
      location = null; // proceed without it -- see class doc
    }
    _emit(SosDispatchRecord(event: event, status: SosDispatchStatus.sending, location: location));

    final payload = SosDispatchPayload(
      event: event,
      location: location,
      driverName: driverName,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );

    // Both channels are attempted regardless of the other's outcome --
    // data and SMS are redundant paths (01_REQUIREMENTS.md), not a
    // primary/fallback pipeline that short-circuits.
    final results = await Future.wait([transport.sendViaData(payload), transport.sendViaSms(payload)]);
    final dataResult = results[0];
    final smsResult = results[1];

    final record = SosDispatchRecord(
      event: event,
      status: (dataResult.ok || smsResult.ok) ? SosDispatchStatus.sent : SosDispatchStatus.failed,
      location: location,
      dataChannelResult: dataResult,
      smsChannelResult: smsResult,
    );
    _emit(record);
    return record;
  }

  void _emit(SosDispatchRecord record) {
    if (!_controller.isClosed) _controller.add(record);
  }

  void dispose() => _controller.close();
}
