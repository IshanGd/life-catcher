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

// Applies to EVERY auto- or manually-triggered SOS (crash fusion AND panic
// button). Whether the panic-button path should instead be silent / use a
// different window for assault scenarios is an OPEN DESIGN DECISION for a
// human to make — see firmware/README.md. Until then it uses this same
// window and the buzzer, matching the locked crash-path behaviour.
constexpr bool kPanicUsesCancelWindow = true;

// --- BLE ---------------------------------------------------------------
constexpr uint32_t kStatusNotifyIntervalMs = 1'000;
constexpr uint32_t kBleLinkTimeoutMs       = 3'000;   // no central -> fail visibly

// --- Fusion (ADR-4: never a single-sensor trigger) --------------------
// A crash is only declared when the IMU window AND the piezo agree within
// this correlation window.
constexpr uint32_t kFusionPairWindowMs = 400;

}  // namespace cfg
