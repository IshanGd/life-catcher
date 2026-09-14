// MPU6050 accel + gyro driver (01_REQUIREMENTS.md §4.1 "Crash/tilt detection").
// Emits helmet::core::ImuSample in the ML pipeline's units: accel in g, gyro
// in deg/s (ml/config.py).
//
// Talks to the chip over raw I2C registers rather than Adafruit_MPU6050:
// several "GY-521" boards on the market ship an MPU6500 die instead of a
// genuine MPU6050 (same register map, different WHO_AM_I — 0x70 vs 0x68),
// and Adafruit's library hard-rejects anything but 0x68. Begin() accepts
// both IDs; everything past that point is the same register interface on
// both chips.
#pragma once

#include "core/imu_window.h"

namespace helmet::sensors {

class ImuMpu6050 {
 public:
  // Returns false if the device is not found on I2C, or reports a chip ID
  // that isn't a known MPU6050/MPU6500-compatible part.
  bool Begin(int sda, int scl, uint8_t addr = 0x68);

  // True when a fresh sample was read into `out` (rate-limited to 50 Hz).
  bool Read(helmet::core::ImuSample& out, uint32_t now_ms);

  bool ok() const { return ok_; }

 private:
  bool WriteReg(uint8_t reg, uint8_t value);
  bool ReadBytes(uint8_t reg, uint8_t* buf, size_t len);

  bool ok_ = false;
  uint8_t addr_ = 0x68;
  uint32_t last_ms_ = 0;
  static constexpr uint32_t kPeriodMs = 1000 / 50;  // 50 Hz
};

}  // namespace helmet::sensors
