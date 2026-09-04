// Versioned BLE data contract (helmet -> app), 02_ARCHITECTURE.md §4.
//
// Framework-agnostic: no Arduino, no NimBLE. Serialises to the JSON strings
// the companion app consumes. Host-tested in test/test_ble_schema/.
//
// 03_RULES.md §4: the schema is versioned. `kSchemaVersion` is bumped only on
// a BREAKING field change (removed/renamed/retyped field), and every bump is
// noted in 02_ARCHITECTURE.md §4. Adding optional fields is not breaking.
#pragma once

#include <cstdint>
#include <string>

#ifndef HELMET_FW_VERSION
#define HELMET_FW_VERSION "0.0.0-dev"
#endif

namespace helmet::schema {

constexpr int kSchemaVersion = 1;

// ---------------------------------------------------------------------------
// event_type — MUST match the ML label set in 01_REQUIREMENTS.md §4.3
// (normal_riding, pothole_bump, harsh_brake, crash_impact) plus the two
// non-ML-triggered events (panic_button, alcohol_flag).
// ---------------------------------------------------------------------------
enum class EventType : uint8_t {
  kNormalRiding = 0,
  kPotholeBump,
  kHarshBrake,
  kCrashImpact,
  kPanicButton,
  kAlcoholFlag,   // produced in Phase 3; present here so the enum is stable
};

const char* ToString(EventType t);

// Which sensors fused to produce an event (ADR-4). An emergency event
// (kCrashImpact) is only valid with >= 2 distinct sources.
enum SensorBit : uint8_t {
  kSrcNone   = 0,
  kSrcMpu6050 = 1 << 0,
  kSrcPiezo   = 1 << 1,
  kSrcFsr     = 1 << 2,
  kSrcPanic   = 1 << 3,
  kSrcMq3     = 1 << 4,   // Phase 3 alcohol check -- single-sensor by design
                          // (ADR-5 makes this a gate, not a fusion-confirmed SOS)
};

// ---------------------------------------------------------------------------
// Status payload — periodic, on the STATUS characteristic.
//   {"schema":1,"helmet_worn":true,"pre_ride_passed":false,
//    "battery_pct":78,"firmware":"0.1.0-phase2","ble_link":true,"event":null}
// `ble_link` is an additive field (not in the doc's minimal v1) so the app
// can show link state; noted in 02_ARCHITECTURE.md §4.
// ---------------------------------------------------------------------------
struct StatusPayload {
  bool        helmet_worn     = false;
  bool        pre_ride_passed = false;   // Phase 3 gates this; false for now
  int         battery_pct     = -1;      // -1 = unknown / not wired yet
  const char* firmware        = HELMET_FW_VERSION;
  bool        ble_link        = false;
};

// ---------------------------------------------------------------------------
// Event payload — on the EVENT characteristic when something is flagged.
//   {"schema":1,"event_type":"crash_impact","severity_score":84,
//    "confirmed_by":["mpu6050","piezo"],"timestamp_device_ms":1234567,
//    "awaiting_cancel":true,"cancel_window_sec":10,
//    "cancelled":false,"confirmed":false,"cancel_reason":""}
// `cancelled`/`confirmed`/`cancel_reason` are additive lifecycle fields:
//   - fired:      awaiting_cancel=true,  cancelled=false, confirmed=false
//   - cancelled:  awaiting_cancel=false, cancelled=true   (03_RULES.md §2:
//                 the cancellation is ITSELF logged as an event, never
//                 silently discarded)
//   - confirmed:  awaiting_cancel=false, confirmed=true   -> app dispatches SOS
// Non-emergency events (pothole_bump/harsh_brake for ride scoring) are sent
// once with awaiting_cancel=false and no lifecycle follow-up.
// ---------------------------------------------------------------------------
struct EventPayload {
  EventType   event_type        = EventType::kNormalRiding;
  int         severity_score    = 0;     // 0..100
  uint8_t     confirmed_by      = kSrcNone;   // OR of SensorBit
  uint32_t    timestamp_device_ms = 0;
  bool        awaiting_cancel   = false;
  int         cancel_window_sec = 0;
  bool        cancelled         = false;
  bool        confirmed         = false;
  std::string cancel_reason;             // "driver", "" otherwise
};

// Serialise to a compact JSON string (allocates; fine for BLE-notify sizes).
std::string Serialize(const StatusPayload& s);
std::string Serialize(const EventPayload& e);

// True when `confirmed_by` names at least two distinct sources — the
// invariant every emergency (crash) event must satisfy (ADR-4).
bool IsFusionConfirmed(uint8_t confirmed_by);

}  // namespace helmet::schema
