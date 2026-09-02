// MPU6050 accel + gyro driver (01_REQUIREMENTS.md §4.1 "Crash/tilt detection").
// Emits helmet::core::ImuSample in the ML pipeline's units: accel in g, gyro
// in deg/s (ml/config.py). Adafruit's library returns m/s^2 and rad/s, so we
// convert here — one place.
#pragma once

#include "core/imu_window.h"

namespace helmet::sensors {

class ImuMpu6050 {
 public:
  // Returns false if the device is not found on I2C.
  bool Begin(int sda, int scl, uint8_t addr = 0x68);

  // True when a fresh sample was read into `out` (rate-limited to 50 Hz).
  bool Read(helmet::core::ImuSample& out, uint32_t now_ms);

  bool ok() const { return ok_; }

 private:
  bool ok_ = false;
  uint32_t last_ms_ = 0;
  static constexpr uint32_t kPeriodMs = 1000 / 50;  // 50 Hz
};

}  // namespace helmet::sensors
