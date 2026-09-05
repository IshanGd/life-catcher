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
    required this.emergencyContactSet,
  });

  final String name;
  final String avatarInitials;
  final String platform;
  final String vehicleType;
  final String deviceId;
  final PairingStatus pairingStatus;
  final bool emergencyContactSet;
}
