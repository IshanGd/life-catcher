/// Ride behavior scoring (01_REQUIREMENTS.md §4.4, 05_DESIGN.md §2.1/§2.2).
///
/// 04_PHASES.md tracked this as "Concept agreed (accel + phone GPS) --
/// scoring model/thresholds not yet designed." This is that first design:
/// a plain, framework-agnostic function (no Flutter imports, mirrors
/// firmware/src/core/crash_fusion.h's separation of pure logic from I/O)
/// so it can be unit-tested and re-tuned without touching any screen.
///
/// PROVISIONAL, same status as firmware/src/core/crash_fusion.cpp's
/// thresholds: hand-picked weights to get scoring end-to-end, not fitted
/// against real fleet data. Re-tune once pilot data exists
/// (04_PHASES.md Phase 6).
library;

/// Per-100km harsh-event rates for one period (a day, a shift) --
/// normalizing by distance is intentional (05_DESIGN.md §2.2), never a raw
/// count.
class RideBehaviorInput {
  const RideBehaviorInput({
    required this.harshBrakingPer100km,
    required this.harshAccelPer100km,
    required this.corneringPer100km,
  });

  final double harshBrakingPer100km;
  final double harshAccelPer100km;
  final double corneringPer100km;
}

class RideBehaviorScorer {
  RideBehaviorScorer._();

  // Points deducted per harsh event per 100km. PROVISIONAL -- see file header.
  static const kHarshBrakingWeight = 3.0;
  static const kHarshAccelWeight = 2.5;
  static const kCorneringWeight = 2.0;

  // Caps how far a single period's penalty can drag the score down, so one
  // very sparse-data day (e.g. 1 harsh event over a very short ride) can't
  // read as "as bad as reckless all-day riding." PROVISIONAL.
  static const kMaxPenalty = 60.0;

  /// 0-100. 100 == no harsh events at all in the period.
  static int score(RideBehaviorInput input) {
    final rawPenalty = input.harshBrakingPer100km * kHarshBrakingWeight +
        input.harshAccelPer100km * kHarshAccelWeight +
        input.corneringPer100km * kCorneringWeight;
    final penalty = rawPenalty.clamp(0, kMaxPenalty);
    return (100 - penalty).round().clamp(0, 100);
  }
}
