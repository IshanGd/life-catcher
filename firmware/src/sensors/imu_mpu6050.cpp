#include "sensors/imu_mpu6050.h"

#include <Arduino.h>
#include <Wire.h>

namespace helmet::sensors {

namespace {
constexpr uint8_t kRegWhoAmI = 0x75;
constexpr uint8_t kRegPwrMgmt1 = 0x6B;
constexpr uint8_t kRegConfig = 0x1A;       // DLPF
constexpr uint8_t kRegGyroConfig = 0x1B;
constexpr uint8_t kRegAccelConfig = 0x1C;
constexpr uint8_t kRegAccelXoutH = 0x3B;   // burst-read start: accel, temp, gyro

constexpr uint8_t kChipIdMpu6050 = 0x68;
constexpr uint8_t kChipIdMpu6500 = 0x70;  // common substitute on "GY-521" boards

// Full-scale settings written to GYRO_CONFIG / ACCEL_CONFIG (FS_SEL=3 /
// AFS_SEL=3, bits [4:3]) match the +-2000 dps / +-16 g ranges the old
// Adafruit-based driver used (see git history) so downstream thresholds in
// src/core/ don't need retuning.
constexpr uint8_t kGyroConfig2000Dps = 0x18;
constexpr uint8_t kAccelConfig16G = 0x18;
constexpr float kAccelLsbPerG = 2048.0f;    // +-16 g full scale
constexpr float kGyroLsbPerDps = 16.4f;     // +-2000 dps full scale
}  // namespace

bool ImuMpu6050::Begin(int sda, int scl, uint8_t addr) {
  addr_ = addr;
  Wire.begin(sda, scl);

  uint8_t whoami = 0;
  if (!ReadBytes(kRegWhoAmI, &whoami, 1)) {
    ok_ = false;
    return false;
  }
  if (whoami != kChipIdMpu6050 && whoami != kChipIdMpu6500) {
    Serial.printf("IMU: unrecognised chip id 0x%02X at addr 0x%02X\n", whoami, addr_);
    ok_ = false;
    return false;
  }
  Serial.printf("IMU: chip id 0x%02X (%s)\n", whoami,
                whoami == kChipIdMpu6050 ? "MPU6050" : "MPU6500-compatible");

  WriteReg(kRegPwrMgmt1, 0x01);   // wake from sleep, PLL clock w/ X-gyro reference
  delay(10);
  WriteReg(kRegConfig, 0x04);           // DLPF ~21 Hz (matches old MPU6050_BAND_21_HZ)
  WriteReg(kRegGyroConfig, kGyroConfig2000Dps);
  WriteReg(kRegAccelConfig, kAccelConfig16G);

  ok_ = true;
  return true;
}

bool ImuMpu6050::Read(helmet::core::ImuSample& out, uint32_t now_ms) {
  if (!ok_) return false;
  if ((now_ms - last_ms_) < kPeriodMs) return false;
  last_ms_ = now_ms;

  uint8_t buf[14];  // accel x/y/z, temp, gyro x/y/z — 2 bytes each, big-endian
  if (!ReadBytes(kRegAccelXoutH, buf, sizeof(buf))) return false;

  auto be16 = [](uint8_t hi, uint8_t lo) -> int16_t {
    return static_cast<int16_t>((static_cast<uint16_t>(hi) << 8) | lo);
  };

  int16_t raw_ax = be16(buf[0], buf[1]);
  int16_t raw_ay = be16(buf[2], buf[3]);
  int16_t raw_az = be16(buf[4], buf[5]);
  // buf[6..7] = temperature — unused here.
  int16_t raw_gx = be16(buf[8], buf[9]);
  int16_t raw_gy = be16(buf[10], buf[11]);
  int16_t raw_gz = be16(buf[12], buf[13]);

  out.ax = raw_ax / kAccelLsbPerG;
  out.ay = raw_ay / kAccelLsbPerG;
  out.az = raw_az / kAccelLsbPerG;
  out.gx = raw_gx / kGyroLsbPerDps;
  out.gy = raw_gy / kGyroLsbPerDps;
  out.gz = raw_gz / kGyroLsbPerDps;
  return true;
}

bool ImuMpu6050::WriteReg(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(addr_);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool ImuMpu6050::ReadBytes(uint8_t reg, uint8_t* buf, size_t len) {
  Wire.beginTransmission(addr_);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;  // repeated start, no stop
  if (Wire.requestFrom(addr_, static_cast<uint8_t>(len)) != len) return false;
  for (size_t i = 0; i < len; i++) buf[i] = Wire.read();
  return true;
}

}  // namespace helmet::sensors
