/// 05_DESIGN.md §2.4 "Profile" tab.
enum PairingStatus { paired, pairing, unpaired }

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.avatarInitials,
    required this.platform,
    required this.vehicleType,
    required this.deviceId,
    required this.pairingStatus,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String name;
  final String avatarInitials;
  final String platform;
  final String vehicleType;
  final String deviceId;
  final PairingStatus pairingStatus;

  /// null == not set. 01_REQUIREMENTS.md's SOS relay sends here on a
  /// confirmed crash/panic event (lib/logic/sos_relay.dart) -- so unlike
  /// the Phase 4 "Set ✓ / Not set" pill (05_DESIGN.md §2.4), this needs the
  /// actual contact, not just a boolean.
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  bool get emergencyContactSet => emergencyContactPhone != null;
}
