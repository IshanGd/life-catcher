// NVS-backed ICalibrationStore for the MQ-3 per-unit calibration record.
// 03_RULES.md §2: per-unit calibration is an assembly-line artifact that
// must survive power cycles and must never be a firmware constant.
#pragma once

#include <Preferences.h>

#include "core/alcohol_calibration.h"

namespace helmet::sensors {

class Mq3CalibrationStore : public helmet::core::ICalibrationStore {
 public:
  helmet::core::AlcoholCalibration Load() override {
    Preferences p;
    p.begin("mq3cal", /*readOnly=*/true);
    helmet::core::AlcoholCalibration c;
    c.valid = p.getBool("valid", false);
    c.baseline_adc = p.getInt("baseline", 0);
    c.calibrated_at_ms = p.getULong("at_ms", 0);
    p.end();
    return c;
  }

  void Save(const helmet::core::AlcoholCalibration& c) override {
    Preferences p;
    p.begin("mq3cal", /*readOnly=*/false);
    p.putBool("valid", c.valid);
    p.putInt("baseline", c.baseline_adc);
    p.putULong("at_ms", c.calibrated_at_ms);
    p.end();
  }
};

}  // namespace helmet::sensors
