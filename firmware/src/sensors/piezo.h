// Piezo impact sensor (01_REQUIREMENTS.md §4.1). The SECOND, independent
// signal in the crash fusion (ADR-4) — a hard mechanical shock the IMU alone
// can't distinguish from a big pothole.
//
// Wiring: piezo across a ~1 MΩ bleed resistor into an ADC pin, with a diode
// clamp to 3V3/GND. A strike produces a fast voltage spike; we latch the
// most recent spike time so the fusion stage can ask "was there an impact in
// the last N ms?".
#pragma once

#include <Arduino.h>

namespace helmet::sensors {

class Piezo {
 public:
  void Begin(int adc_pin, int threshold_counts = 900) {
    pin_ = adc_pin;
    threshold_ = threshold_counts;
    analogReadResolution(12);              // 0..4095
    pinMode(pin_, INPUT);
  }

  // Call frequently (faster than the IMU rate). Latches spike timestamps.
  void Update(uint32_t now_ms) {
    int v = analogRead(pin_);
    if (v > peak_) peak_ = v;
    if (v >= threshold_ && (now_ms - last_impact_ms_) > kRefractoryMs) {
      last_impact_ms_ = now_ms;
      last_impact_peak_ = v;
    }
  }

  bool ImpactSince(uint32_t since_ms, uint32_t now_ms) const {
    return last_impact_ms_ != 0 && (now_ms - last_impact_ms_) <= since_ms;
  }
  uint32_t last_impact_ms() const { return last_impact_ms_; }
  int last_impact_peak() const { return last_impact_peak_; }

  int TakePeak() { int p = peak_; peak_ = 0; return p; }   // for self-test

 private:
  static constexpr uint32_t kRefractoryMs = 50;
  int pin_ = -1;
  int threshold_ = 900;
  int peak_ = 0;
  int last_impact_peak_ = 0;
  uint32_t last_impact_ms_ = 0;
};

}  // namespace helmet::sensors
