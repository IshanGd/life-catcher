// Compile-time configuration for the helmet firmware.
// Values here are prototype defaults; anything that must vary PER PHYSICAL
// UNIT (e.g. sensor calibration) must NOT live here as a constant — see
// 03_RULES.md §2. The MQ-3 alcohol sensor and its per-unit calibration are
// Phase 3 and deliberately absent from this build.
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

}  // namespace cfg
