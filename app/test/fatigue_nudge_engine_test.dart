// Host tests for the fatigue-nudge state machine (01_REQUIREMENTS.md §4.4,
// 05_DESIGN.md §2.1.6). 04_PHASES.md tracked this as concept-only until now.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_helmet_app/logic/fatigue_nudge_engine.dart';

void main() {
  final start = DateTime(2026, 1, 1, 8, 0, 0);

  test('no nudge before the threshold is crossed', () {
    final engine = FatigueNudgeEngine(continuousSince: start);
    engine.tick(start.add(const Duration(hours: 2, minutes: 59)));
    expect(engine.popNudge(), isNull);
    expect(engine.isBreakOverdue, isFalse);
  });

  test('exactly one nudge fires the instant the threshold is crossed', () {
    final engine = FatigueNudgeEngine(continuousSince: start);
    final crossingTime = start.add(FatigueNudgeEngine.kBreakSuggestionThreshold);
    engine.tick(crossingTime);

    final nudge = engine.popNudge();
    expect(nudge, isNotNull);
    expect(nudge!.firedAt, crossingTime);
    expect(nudge.continuousDuration, FatigueNudgeEngine.kBreakSuggestionThreshold);

    // Draining again yields nothing -- it fired once for this streak.
    expect(engine.popNudge(), isNull);
  });

  test('ticking repeatedly past the threshold does not re-fire', () {
    final engine = FatigueNudgeEngine(continuousSince: start);
    engine.tick(start.add(const Duration(hours: 3)));
    engine.popNudge();
    engine.tick(start.add(const Duration(hours: 3, minutes: 30)));
    engine.tick(start.add(const Duration(hours: 4)));
    expect(engine.popNudge(), isNull);
    expect(engine.isBreakOverdue, isTrue);
  });

  test('breakSuggestedIn counts down and floors at zero, never negative', () {
    final engine = FatigueNudgeEngine(continuousSince: start);
    expect(engine.breakSuggestedIn(start), FatigueNudgeEngine.kBreakSuggestionThreshold);
    expect(
      engine.breakSuggestedIn(start.add(const Duration(hours: 1))),
      FatigueNudgeEngine.kBreakSuggestionThreshold - const Duration(hours: 1),
    );
    expect(engine.breakSuggestedIn(start.add(const Duration(hours: 10))), Duration.zero);
  });

  test('recordBreak resets the streak so a nudge can fire again later', () {
    final engine = FatigueNudgeEngine(continuousSince: start);
    engine.tick(start.add(const Duration(hours: 3)));
    engine.popNudge();
    expect(engine.isBreakOverdue, isTrue);

    final breakTime = start.add(const Duration(hours: 3, minutes: 20));
    engine.recordBreak(breakTime);
    expect(engine.isBreakOverdue, isFalse);
    expect(engine.continuousDuration(breakTime), Duration.zero);

    engine.tick(breakTime.add(const Duration(hours: 1)));
    expect(engine.popNudge(), isNull); // not yet 3h into the new streak

    final secondCrossing = breakTime.add(FatigueNudgeEngine.kBreakSuggestionThreshold);
    engine.tick(secondCrossing);
    expect(engine.popNudge(), isNotNull);
  });
}
