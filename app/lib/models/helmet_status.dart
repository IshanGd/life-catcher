/// Mirrors the firmware's schema::StatusPayload (firmware/src/core/ble_schema.h)
/// plus the phone/app-side computed fields (safety score, trend, shift
/// timer) that the docs say the app owns, not the helmet
/// (02_ARCHITECTURE.md §5). This is the shape HelmetDataService streams.
enum PreRideStatus { passed, failed, pending }

class HelmetStatus {
  const HelmetStatus({
    required this.driverName,
    required this.platformName,
    required this.shiftDuration,
    required this.helmetWorn,
    required this.preRide,
    required this.bleConnected,
    required this.batteryPct,
    required this.firmwareVersion,
    required this.safetyScoreToday,
    required this.safetyScoreDeltaVsYesterday,
    required this.riskTrend7dScore,
    required this.riskTrendImproving,
    required this.continuousShiftDuration,
    required this.breakSuggestedIn,
  });

  final String driverName;
  final String platformName;
  final Duration shiftDuration;

  final bool helmetWorn;
  final PreRideStatus preRide;
  final bool bleConnected;
  final int? batteryPct; // null == unknown, matches firmware's -1 sentinel
  final String firmwareVersion;

  final int safetyScoreToday;
  final int safetyScoreDeltaVsYesterday;

  final int riskTrend7dScore;
  final bool riskTrendImproving;

  final Duration continuousShiftDuration;
  final Duration breakSuggestedIn;
}
