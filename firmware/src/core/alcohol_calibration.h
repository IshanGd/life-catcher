// Per-unit MQ-3 calibration record + storage interface.
//
// 03_RULES.md §2: "Per-unit calibration steps (e.g. MQ-3) are assembly-line
// requirements, not firmware constants." The MQ-3's baseline resistance
// drifts unit-to-unit and with storage age, so every physical helmet needs
// its own clean-air baseline before a pre-ride reading means anything.
//
// This is a screening baseline for an internal ride-readiness gate, not a
// forensic instrument -- never call this a "breathalyzer" or "BAC" reading
// in code, logs, or UI strings (03_RULES.md §2 alcohol-sensor-framing rule).
//
// Framework-agnostic; host-tested alongside core/preride_check.h.
#pragma once

#include <cstdint>

namespace helmet::core {

struct AlcoholCalibration {
  bool     valid            = false;  // false until an assembly-line calibration has run
  int      baseline_adc     = 0;      // clean-air reading, warmed-up, averaged
  uint32_t calibrated_at_ms = 0;      // device-relative timestamp of the calibration run
};

// Persists AlcoholCalibration across power cycles. The ESP32 target backs
// this with NVS (sensors/mq3_calibration_store.h); host tests use a plain
// in-memory value -- no fake needed since the state machine only takes an
// AlcoholCalibration by value, never touches storage itself.
class ICalibrationStore {
 public:
  virtual ~ICalibrationStore() = default;
  virtual AlcoholCalibration Load() = 0;
  virtual void Save(const AlcoholCalibration& c) = 0;
};

}  // namespace helmet::core
