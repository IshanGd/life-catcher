/// Shift fatigue / nudge logic (01_REQUIREMENTS.md §4.4, 05_DESIGN.md
/// §2.1.6 "Fatigue watch"). 04_PHASES.md tracked this as "Concept agreed --
/// nudge timing/thresholds not yet designed." This is that first design.
///
/// Framework-agnostic (time passed in as `now`, mirrors
/// firmware/src/core/sos_state_machine.h's style: pure state + a
/// pop-outgoing-events queue) so it's unit-testable and swappable without
/// touching a screen.
///
/// PROVISIONAL: the break-suggestion threshold is a single hand-picked
/// constant, not a designed model (e.g. it doesn't yet vary by time of day
/// or account for micro-breaks). Re-tune once real shift-pattern data
/// exists (04_PHASES.md Phase 6).
library;

class FatigueNudge {
  const FatigueNudge({required this.firedAt, required this.continuousDuration});
  final DateTime firedAt;
  final Duration continuousDuration;
}

class FatigueNudgeEngine {
  // The public param can't be named after the private field across library
  // boundaries, so this stays an explicit assignment.
  // ignore: prefer_initializing_formals
  FatigueNudgeEngine({required DateTime continuousSince}) : _continuousSince = continuousSince;

  /// Continuous riding this long triggers exactly one nudge per streak.
  static const kBreakSuggestionThreshold = Duration(hours: 3);

  DateTime _continuousSince;
  bool _nudgeFiredThisStreak = false;
  final List<FatigueNudge> _outgoing = [];

  Duration continuousDuration(DateTime now) => now.difference(_continuousSince);

  /// Zero once the threshold has passed -- never negative, so the UI can
  /// show "Break suggested now" instead of a confusing negative countdown.
  Duration breakSuggestedIn(DateTime now) {
    final remaining = kBreakSuggestionThreshold - continuousDuration(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isBreakOverdue => _nudgeFiredThisStreak;

  /// Call on every status tick. Enqueues exactly one [FatigueNudge] the
  /// instant continuous riding crosses the threshold; does nothing on
  /// subsequent ticks until [recordBreak] resets the streak.
  void tick(DateTime now) {
    if (_nudgeFiredThisStreak) return;
    if (continuousDuration(now) >= kBreakSuggestionThreshold) {
      _nudgeFiredThisStreak = true;
      _outgoing.add(FatigueNudge(firedAt: now, continuousDuration: continuousDuration(now)));
    }
  }

  /// The driver took a break (helmet off, explicit ack, etc.) -- starts a
  /// fresh continuous-riding streak.
  void recordBreak(DateTime now) {
    _continuousSince = now;
    _nudgeFiredThisStreak = false;
  }

  /// Drain one nudge fired since the last call, oldest first. Returns null
  /// when empty -- the Dart-idiomatic equivalent of
  /// SosStateMachine::PopOutgoing's out-param queue in the firmware.
  FatigueNudge? popNudge() => _outgoing.isEmpty ? null : _outgoing.removeAt(0);
}
