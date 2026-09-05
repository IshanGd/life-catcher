/// The app-side shape of a fusion-confirmed SOS -- fires once an SOS
/// finishes its 10s confirm/cancel window without being cancelled
/// (firmware: SosStateMachine emits `EventPayload{confirmed:true}` on the
/// BLE EVENT characteristic, 02_ARCHITECTURE.md §4). A cancelled SOS never
/// produces one of these; it only ever shows up in the event history.
///
/// ADR-4 / 03_RULES.md §1: by the time this reaches the app, the crash
/// path has already been fusion-confirmed and has already sat through the
/// human-cancellable window on the helmet itself. The app's only job from
/// here is the phone-side relay (ADR-1) -- it does not re-decide anything.
enum SosTriggerType { crashImpact, panicButton }

class SosEvent {
  const SosEvent({
    required this.type,
    required this.severityScore,
    required this.confirmedBy,
    required this.timestampDeviceMs,
  });

  final SosTriggerType type;
  final int severityScore;

  /// e.g. ["mpu6050", "piezo"] -- mirrors schema::EventPayload.confirmed_by
  /// (firmware/src/core/ble_schema.h). Shown to the driver as a trust
  /// signal, same instinct as the insurer "sensor fusion trail" in
  /// 05_DESIGN.md §3.2 -- don't imply more certainty than the signal has.
  final List<String> confirmedBy;
  final int timestampDeviceMs;
}
