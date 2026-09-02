// Fixed-size ring buffer of IMU samples + the window features the fusion
// stage needs. Framework-agnostic; host-tested.
//
// Units and window shape match the ML pipeline exactly (ml/config.py,
// ml/features.py): accel in g, gyro in deg/s, 50 Hz, 100-sample (2 s)
// window. Feature names mirror features.py so a ported RF model can consume
// them later (ADR-3).
#pragma once

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>

#include "build_config.h"

namespace helmet::core {

struct ImuSample {
  float ax, ay, az;   // g
  float gx, gy, gz;   // deg/s
};

struct WindowFeatures {
  bool  full = false;          // window has kImuWindowSamples samples

  float amag_max = 0, amag_mean = 0, amag_std = 0, amag_min = 0;
  float gmag_max = 0, gmag_mean = 0, gmag_std = 0;
  float jerk_absmax = 0;       // |d|amag||/dt, g/s

  // sustained tip-over cues (gravity leaving the upright -az axis)
  float ax_mean = 0, ay_mean = 0, az_mean = 0;
  float ax_second_half_mean = 0, ay_second_half_mean = 0, az_second_half_mean = 0;

  // gyro magnitude second half / first half. Pothole spike -> recovers ->
  // low-ish ratio; crash -> settled on the ground -> ratio ~ 0; braking ramps
  // up -> ratio > 1. (See ml/features.py::g_recovery_ratio.)
  float g_recovery_ratio = 1.0f;
  float gmag_first_half_max = 0, gmag_second_half_max = 0;
};

class ImuWindow {
 public:
  static constexpr size_t kN = cfg::kImuWindowSamples;

  void Push(const ImuSample& s) {
    buf_[head_] = s;
    head_ = (head_ + 1) % kN;
    if (count_ < kN) ++count_;
  }

  void Clear() { head_ = 0; count_ = 0; }
  bool Full() const { return count_ == kN; }
  size_t Count() const { return count_; }

  // Compute features over the samples currently held, oldest-first.
  WindowFeatures Compute() const {
    WindowFeatures f;
    if (count_ == 0) return f;
    f.full = (count_ == kN);

    const size_t n = count_;
    const size_t half = n / 2;
    const float fs = static_cast<float>(cfg::kImuSampleRateHz);

    float amag[kN];
    float sx = 0, sy = 0, sz = 0;
    float a_sum = 0, a_sum2 = 0, g_sum = 0, g_sum2 = 0;
    float g_first_sum = 0, g_second_sum = 0;
    float sx2h = 0, sy2h = 0, sz2h = 0;

    f.amag_min = 1e9f;
    for (size_t i = 0; i < n; ++i) {
      const ImuSample& s = at(i);
      float am = std::sqrt(s.ax * s.ax + s.ay * s.ay + s.az * s.az);
      float gm = std::sqrt(s.gx * s.gx + s.gy * s.gy + s.gz * s.gz);
      amag[i] = am;

      if (am > f.amag_max) f.amag_max = am;
      if (am < f.amag_min) f.amag_min = am;
      if (gm > f.gmag_max) f.gmag_max = gm;
      a_sum += am; a_sum2 += am * am;
      g_sum += gm; g_sum2 += gm * gm;

      sx += s.ax; sy += s.ay; sz += s.az;

      if (i < half) {
        g_first_sum += gm;
        if (gm > f.gmag_first_half_max) f.gmag_first_half_max = gm;
      } else {
        g_second_sum += gm;
        if (gm > f.gmag_second_half_max) f.gmag_second_half_max = gm;
        sx2h += s.ax; sy2h += s.ay; sz2h += s.az;
      }
    }

    f.amag_mean = a_sum / n;
    f.amag_std  = std_from_sums(a_sum, a_sum2, n);
    f.gmag_mean = g_sum / n;
    f.gmag_std  = std_from_sums(g_sum, g_sum2, n);

    f.ax_mean = sx / n; f.ay_mean = sy / n; f.az_mean = sz / n;
    const size_t sh = n - half;
    if (sh > 0) {
      f.ax_second_half_mean = sx2h / sh;
      f.ay_second_half_mean = sy2h / sh;
      f.az_second_half_mean = sz2h / sh;
    }

    float g_first_mean  = half ? g_first_sum / half : 0.0f;
    float g_second_mean = sh ? g_second_sum / sh : 0.0f;
    f.g_recovery_ratio = g_second_mean / (g_first_mean + 1e-6f);

    float jmax = 0;
    for (size_t i = 1; i < n; ++i) {
      float j = std::fabs(amag[i] - amag[i - 1]) * fs;
      if (j > jmax) jmax = j;
    }
    f.jerk_absmax = jmax;
    return f;
  }

 private:
  const ImuSample& at(size_t logical) const {
    // logical 0 == oldest sample currently held
    size_t start = (count_ == kN) ? head_ : 0;
    return buf_[(start + logical) % kN];
  }
  static float std_from_sums(float sum, float sum2, size_t n) {
    float m = sum / n;
    float v = sum2 / n - m * m;
    return v > 0 ? std::sqrt(v) : 0.0f;
  }

  std::array<ImuSample, kN> buf_{};
  size_t head_ = 0;
  size_t count_ = 0;
};

}  // namespace helmet::core
