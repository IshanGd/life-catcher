/// The phone's own GPS fix (ADR-1: the helmet has no GPS of its own --
/// the app is the source of truth for location, 02_ARCHITECTURE.md §4).
class GeoLocation {
  const GeoLocation({required this.latitude, required this.longitude, this.accuracyMeters});

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  String toDisplayString() {
    final coords = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    if (accuracyMeters == null) return coords;
    return '$coords (±${accuracyMeters!.round()}m)';
  }
}
