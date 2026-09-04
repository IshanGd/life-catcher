// Alcohol pre-ride "check-in" state machine (ADR-5, 01_REQUIREMENTS.md §4.1).
//
// Runs once per check-in, meant to be started post helmet-donning / pre-"go
// online" (the app decides when, via the BLE "start_check" command):
//   kWarmingUp -> kSampling -> kPassed | kFailed
// or straight to kUncalibrated if the unit has no valid baseline (03_RULES
// §2: never guess a threshold for a device that hasn't been calibrated).
//
// This is a SCREENING GATE, not the SOS path: a fail produces one
// `alcohol_flag` event and flips StatusPayload.pre_ride_passed -- it never
// goes through SosStateMachine's confirm/cancel/dispatch flow, and there is
// no code path from this result to vehicle ignition (03_RULES.md §1 -- no
// such path exists here or anywhere).
//
// Never describe a result as a "breathalyzer" or "BAC" reading anywhere
// this class's output reaches (03_RULES.md §2).
//
// Framework-agnostic; host-tested in test/test_preride_check/.
#pragma once

#include <cstdint>

#include "build_config.h"
#include "core/alcohol_calibration.h"
#include "core/ble_schema.h"
#include "core/mq3_sampling.h"

namespace helmet::core {

enum class PreRideResult : uint8_t {
  kNotRun,
  kWarmingUp,
  kSampling,
  kPassed,
  kFailed,
  kUncalibrated,  // no valid per-unit baseline -- can't produce a trustworthy result
};

class PreRideCheckStateMachine {
 public:
  using EventPayload = helmet::schema::EventPayload;

  // Begin a check-in. No-op (returns false) if one is already running.
  bool Start(const AlcoholCalibration& calib, uint32_t now_ms);

  // Advance the warm-up/sampling timer. Call every loop tick.
  void Tick(uint32_t now_ms);

  // One raw ADC reading; ignored outside the warm-up/sampling window.
  void Feed(int raw_adc);

  bool InProgress() const {
    return result_ == PreRideResult::kWarmingUp || result_ == PreRideResult::kSampling;
  }
  PreRideResult result() const { return result_; }
  bool passed() const { return result_ == PreRideResult::kPassed; }
  int last_average_adc() const { return last_average_adc_; }

  // Heater should be powered only while a check is running (battery).
  bool HeaterShouldBeOn() const { return InProgress(); }

  // Drain the single `alcohol_flag` event, if this check failed.
  bool PopOutgoing(EventPayload& out);

 private:
  PreRideResult result_ = PreRideResult::kNotRun;
  AlcoholCalibration calib_{};
  WarmupAverager averager_;
  int last_average_adc_ = 0;
  bool has_outgoing_ = false;
  EventPayload outgoing_{};
};

}  // namespace helmet::core
