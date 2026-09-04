// Compile-time configuration for the helmet firmware.
// Values here are prototype defaults; anything that must vary PER PHYSICAL
// UNIT (e.g. sensor calibration) must NOT live here as a constant — see
// 03_RULES.md §2. The MQ-3's per-unit clean-air baseline lives in
// core::AlcoholCalibration (persisted via core::ICalibrationStore), never
// as a constant in this file — only shared *timing* lives here.
#pragma once

#include <cstdint>

namespace cfg {

// --- Sampling (must match the ML pipeline window: ml/config.py) ----------
constexpr int    kImuSampleRateHz   = 50;
constexpr int    kImuWindowSamples  = 100;      // 2.0 s window
constexpr float  kImuWindowSeconds  = 2.0f;

// --- SOS confirm window -------------------------------------------------
// 03_RULES.md §1: the 10-second cancel window may never be removed, shortened
// below a human-confirmed value, or made skippable by any code path.
constexpr uint32_t kSosCancelWindowMs = 10'000;

// DECIDED (2026-09): the panic button uses the SAME 10 s window + buzzer as a
// crash, matching the locked crash-path behaviour. A silent / no-window
// variant for assault scenarios was considered and rejected for now — it
// would remove a confirm window (03_RULES.md §1). Revisit only with a human
// decision.
constexpr bool kPanicUsesCancelWindow = true;

// --- BLE ---------------------------------------------------------------
constexpr uint32_t kStatusNotifyIntervalMs = 1'000;
constexpr uint32_t kBleLinkTimeoutMs       = 3'000;   // no central -> fail visibly

// --- Fusion (ADR-4: never a single-sensor trigger) --------------------
// A crash is only declared when the IMU window AND the piezo agree within
// this correlation window.
constexpr uint32_t kFusionPairWindowMs = 400;

// --- MQ-3 alcohol pre-ride check (Phase 3, ADR-5) -----------------------
// Timing shared by the live check-in (core/preride_check.h) and the
// per-unit calibration routine (core/mq3_calibration.h). The per-unit
// BASELINE itself is never a constant -- see the file header.
namespace mq3 {
// Heater settle time before a reading is trusted. PROVISIONAL: MQ-3
// datasheets vary widely on this for a device kept powered-down between
// checks; needs bench validation against real warm-up curves before Phase
// 3 hardware bring-up, same caveat as crash_fusion.cpp's thresholds.
constexpr uint32_t kWarmupMs = 20'000;
constexpr uint32_t kSampleWindowMs   = 4'000;   // averaging window once warm
constexpr uint32_t kSampleIntervalMs = 200;     // suggested Feed() cadence
// Fail the check when avg_reading >= baseline * this ratio. Higher reading
// == more ethanol vapor for the common MQ-3 breakout wiring (analog output
// rises with gas concentration). PROVISIONAL, needs re-tuning on real
// hardware against known-clean and known-dosed breath samples.
constexpr float kAlcoholRatioThreshold = 1.40f;
}  // namespace mq3

}  // namespace cfg
