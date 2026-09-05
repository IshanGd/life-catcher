import '../models/geo_location.dart';

/// The phone's own GPS (ADR-1) -- a seam so [SosRelay]
/// (lib/logic/sos_relay.dart) never touches a platform location API
/// directly. A real implementation on a mobile target would use the
/// `geolocator` package (or platform channels); there is no cross-platform
/// browser API worth depending on for this, and web isn't the real target
/// for "the phone's own GPS" anyway -- so this stays mocked until a real
/// mobile build exists.
abstract class LocationProvider {
  /// Throws if a fix can't be obtained -- [SosRelay] treats that as
  /// "dispatch without a location" rather than blocking the SOS on it.
  Future<GeoLocation> currentLocation();
}

class MockLocationProvider implements LocationProvider {
  MockLocationProvider({this.fixedLocation, this.shouldFail = false, this.delay = const Duration(milliseconds: 400)});

  /// Defaults to a Bengaluru-area coordinate -- consistent with the sample
  /// event locations elsewhere ("MG Road", "Outer Ring Road").
  final GeoLocation? fixedLocation;
  final bool shouldFail;
  final Duration delay;

  @override
  Future<GeoLocation> currentLocation() async {
    await Future.delayed(delay);
    if (shouldFail) throw StateError('GPS fix unavailable');
    return fixedLocation ?? const GeoLocation(latitude: 12.9716, longitude: 77.5946, accuracyMeters: 12);
  }
}
