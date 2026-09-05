import 'geo_location.dart';
import 'sos_event.dart';

enum SosDispatchStatus { locating, sending, sent, failed }

/// What actually gets relayed -- 01_REQUIREMENTS.md: "use the phone's own
/// GPS + data/SMS to notify the emergency contact."
class SosDispatchPayload {
  const SosDispatchPayload({
    required this.event,
    required this.location,
    required this.driverName,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  final SosEvent event;
  final GeoLocation? location; // null if a GPS fix couldn't be obtained in time
  final String driverName;
  final String emergencyContactName;
  final String emergencyContactPhone;
}

/// Result of attempting one relay channel (data or SMS).
class SosChannelResult {
  const SosChannelResult({required this.ok, this.errorMessage});
  final bool ok;
  final String? errorMessage;
}

/// Live status of one dispatch, for the UI banner
/// (lib/widgets/sos_dispatch_banner.dart) -- 03_RULES.md's "fail visibly,
/// not silently" applies here just as much as to the firmware's BLE-link
/// monitor: the driver must see locating/sending/sent/failed, never a
/// silent gap.
class SosDispatchRecord {
  const SosDispatchRecord({
    required this.event,
    required this.status,
    this.location,
    this.dataChannelResult,
    this.smsChannelResult,
  });

  final SosEvent event;
  final SosDispatchStatus status;
  final GeoLocation? location;
  final SosChannelResult? dataChannelResult;
  final SosChannelResult? smsChannelResult;

  /// True once at least one channel got the alert out
  /// (01_REQUIREMENTS.md: data + SMS are redundant paths, not both-required).
  bool get anyChannelSucceeded => (dataChannelResult?.ok ?? false) || (smsChannelResult?.ok ?? false);

  SosDispatchRecord copyWith({
    SosDispatchStatus? status,
    GeoLocation? location,
    SosChannelResult? dataChannelResult,
    SosChannelResult? smsChannelResult,
  }) {
    return SosDispatchRecord(
      event: event,
      status: status ?? this.status,
      location: location ?? this.location,
      dataChannelResult: dataChannelResult ?? this.dataChannelResult,
      smsChannelResult: smsChannelResult ?? this.smsChannelResult,
    );
  }
}
