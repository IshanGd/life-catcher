/// Shared between the driver app's Profile tab (05_DESIGN.md §2.4) and the
/// Fleet-Ops support view (§3.3) -- same `DeviceHealthCard` component.
/// `alcoholCalibrationAge` being surfaced at all is a deliberate trust
/// signal per §2.4; null means "not calibrated yet"
/// (firmware/src/core/preride_check.h's kUncalibrated state).
class DeviceHealth {
  const DeviceHealth({
    required this.batteryPct,
    required this.lastSync,
    required this.firmwareVersion,
    required this.alcoholCalibrationAge,
  });

  final int? batteryPct;
  final DateTime lastSync;
  final String firmwareVersion;
  final Duration? alcoholCalibrationAge;
}
