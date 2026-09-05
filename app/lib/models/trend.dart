/// 05_DESIGN.md §2.2 "Trends" tab data shapes.
class TrendPoint {
  const TrendPoint({required this.label, required this.score});
  final String label; // e.g. "Mon"
  final int score; // 0..100
}

/// Rate, not a raw count -- 05_DESIGN.md §2.2 is explicit that normalizing
/// by distance is intentional.
class HarshEventRate {
  const HarshEventRate({required this.label, required this.ratePer100km});
  final String label;
  final double ratePer100km;
}

class ComplianceStats {
  const ComplianceStats({
    required this.helmetWearRatePct,
    required this.preRideChecksCompleted,
    required this.preRideChecksTotal,
  });
  final int helmetWearRatePct;
  final int preRideChecksCompleted;
  final int preRideChecksTotal;
}
