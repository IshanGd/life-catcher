/// Every row in the Alerts tab / Home "recent events" list
/// (05_DESIGN.md §2.3, §2.1). `EventKind` covers both the literal BLE
/// event_type values from 02_ARCHITECTURE.md §4
/// (normalRiding..alcoholFlag) and the app-only log entries the mock shows
/// alongside them (preRideCheckPassed, firmwareSynced, fatigueNudgeSent,
/// panicButtonSelfTest) -- 05_DESIGN.md §2.3 treats them as one audit trail.
enum EventKind {
  normalRiding,
  potholeBump,
  harshBrake,
  crashImpact,
  panicButton,
  alcoholFlag,
  preRideCheckPassed,
  firmwareSynced,
  fatigueNudgeSent,
  panicButtonSelfTest,
}

class DriverEvent {
  const DriverEvent({
    required this.id,
    required this.kind,
    required this.timestamp,
    required this.description,
    this.location,
    this.cancelled = false,
    this.cancelReason,
  });

  final String id;
  final EventKind kind;
  final DateTime timestamp;
  final String description;
  final String? location;

  /// 05_DESIGN.md §2.1: cancelled/false-positive events are shown honestly,
  /// never hidden. 05_DESIGN.md §5: don't design this transparency away.
  final bool cancelled;
  final String? cancelReason;
}
