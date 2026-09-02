// FSR wear detection (01_REQUIREMENTS.md §4.1). Confirms the helmet is
// actually being worn before ride-mode logic arms. Voltage divider: FSR from
// 3V3 to the ADC node, fixed resistor from the ADC node to GND. Worn ==
// pressure == lower FSR resistance == higher ADC reading.
//
// Hysteresis so a marginal fit doesn't chatter the "worn" state (which would
// chatter the BLE status and any wear-rate metric).
#pragma once

#include <Arduino.h>

namespace helmet::sensors {

class FsrWear {
 public:
  void Begin(int adc_pin, int on_counts = 1500, int off_counts = 900) {
    pin_ = adc_pin;
    on_ = on_counts;
    off_ = off_counts;
    analogReadResolution(12);
    pinMode(pin_, INPUT);
  }

  void Update() {
    int v = analogRead(pin_);
    ema_ = (ema_ < 0) ? v : (ema_ * 7 + v) / 8;      // light smoothing
    if (!worn_ && ema_ >= on_)  worn_ = true;
    if (worn_  && ema_ <= off_) worn_ = false;
  }

  bool Worn() const { return worn_; }
  int raw() const { return ema_; }

 private:
  int pin_ = -1;
  int on_ = 1500, off_ = 900;
  int ema_ = -1;
  bool worn_ = false;
};

}  // namespace helmet::sensors
