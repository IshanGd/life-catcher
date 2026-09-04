// Per-unit MQ-3 calibration routine -- the assembly-line "clean air"
// baseline capture (03_RULES.md §2; firmware/docs/WIRING.md "Per-unit
// calibration"). Produces an AlcoholCalibration for main.cpp to persist via
// ICalibrationStore.
//
// Framework-agnostic; host-tested in test/test_preride_check/.
#pragma once

#include <cstdint>

#include "build_config.h"
#include "core/alcohol_calibration.h"
#include "core/mq3_sampling.h"

namespace helmet::core {

class Mq3CalibrationRoutine {
 public:
  bool InProgress() const { return started_ && !averager_.done(); }
  bool Done() const { return started_ && averager_.done(); }

  // No-op if already running.
  bool Start(uint32_t now_ms) {
    if (InProgress()) return false;
    started_ = true;
    averager_.Start(now_ms, cfg::mq3::kWarmupMs, cfg::mq3::kSampleWindowMs);
    return true;
  }

  void Tick(uint32_t now_ms) { if (started_) averager_.Tick(now_ms); }
  void Feed(int raw_adc) { if (started_) averager_.Feed(raw_adc); }

  // Valid only once Done(). A zero-sample run yields valid=false rather
  // than a garbage baseline (03_RULES §2: never guess a threshold).
  AlcoholCalibration Result(uint32_t now_ms) const {
    AlcoholCalibration c;
    c.valid = Done() && averager_.sample_count() > 0;
    c.baseline_adc = averager_.average();
    c.calibrated_at_ms = now_ms;
    return c;
  }

 private:
  bool started_ = false;
  WarmupAverager averager_;
};

}  // namespace helmet::core
