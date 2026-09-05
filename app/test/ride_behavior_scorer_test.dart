// Host tests for the ride-behavior scoring model (01_REQUIREMENTS.md §4.4).
// 04_PHASES.md tracked this as concept-only until now -- these pin down
// the actual (PROVISIONAL) scoring behavior so a re-tune has a baseline.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helmet_app/logic/ride_behavior_scorer.dart';

void main() {
  test('a perfectly clean ride scores 100', () {
    const input = RideBehaviorInput(harshBrakingPer100km: 0, harshAccelPer100km: 0, corneringPer100km: 0);
    expect(RideBehaviorScorer.score(input), 100);
  });

  test('known rates produce the expected weighted score', () {
    // penalty = 2.1*3 + 1.4*2.5 + 0.6*2 = 6.3 + 3.5 + 1.2 = 11 -> 89
    const input = RideBehaviorInput(harshBrakingPer100km: 2.1, harshAccelPer100km: 1.4, corneringPer100km: 0.6);
    expect(RideBehaviorScorer.score(input), 89);
  });

  test('a very high harsh-event rate is capped, never scores below the floor', () {
    const input = RideBehaviorInput(harshBrakingPer100km: 100, harshAccelPer100km: 100, corneringPer100km: 100);
    // penalty clamps at kMaxPenalty (60) -> score floors at 40.
    expect(RideBehaviorScorer.score(input), 100 - RideBehaviorScorer.kMaxPenalty.round());
  });

  test('score is monotonically non-increasing as any rate rises', () {
    const base = RideBehaviorInput(harshBrakingPer100km: 1, harshAccelPer100km: 1, corneringPer100km: 1);
    const worse = RideBehaviorInput(harshBrakingPer100km: 2, harshAccelPer100km: 1, corneringPer100km: 1);
    expect(RideBehaviorScorer.score(worse), lessThan(RideBehaviorScorer.score(base)));
  });
}
