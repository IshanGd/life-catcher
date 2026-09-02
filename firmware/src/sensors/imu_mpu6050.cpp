#include "sensors/imu_mpu6050.h"

#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Wire.h>

namespace helmet::sensors {

namespace {
constexpr float kG = 9.80665f;               // m/s^2 per g
constexpr float kRadToDeg = 57.2957795f;
Adafruit_MPU6050 g_mpu;
}  // namespace

bool ImuMpu6050::Begin(int sda, int scl, uint8_t addr) {
  Wire.begin(sda, scl);
  ok_ = g_mpu.begin(addr, &Wire);
  if (ok_) {
    // ±16 g so real impacts don't clip the way the DAMOTO ±1.8 g sensor did
    // (ml/README.md §Results). Gyro ±2000 dps for the same reason.
    g_mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
    g_mpu.setGyroRange(MPU6050_RANGE_2000_DEG);
    g_mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);   // < 25 Hz for a 50 Hz stream
  }
  return ok_;
}

bool ImuMpu6050::Read(helmet::core::ImuSample& out, uint32_t now_ms) {
  if (!ok_) return false;
  if ((now_ms - last_ms_) < kPeriodMs) return false;
  last_ms_ = now_ms;

  sensors_event_t a, g, t;
  if (!g_mpu.getEvent(&a, &g, &t)) return false;

  out.ax = a.acceleration.x / kG;
  out.ay = a.acceleration.y / kG;
  out.az = a.acceleration.z / kG;
  out.gx = g.gyro.x * kRadToDeg;
  out.gy = g.gyro.y * kRadToDeg;
  out.gz = g.gyro.z * kRadToDeg;
  return true;
}

}  // namespace helmet::sensors
