// MQ-3 alcohol (ethanol vapor) sensor driver (Phase 3, ADR-5). Gated
// pre-ride check only -- the heater is powered only while a check is
// running (core/preride_check.h / core/mq3_calibration.h decide when) to
// save battery between rides.
//
// This is a chemo-resistive ethanol-vapor screen, NOT a legal breathalyzer
// or BAC measurement -- keep that framing in every log/UI string that
// touches this sensor (03_RULES.md §2).
//
// Wiring: MQ-3 module VCC through a switch transistor on PIN_MQ3_HEATER_EN,
// analog output straight into an ADC1 pin (the module has its own onboard
// load resistor -- no external divider needed). See firmware/docs/WIRING.md.
#pragma once

#include <Arduino.h>

namespace helmet::sensors {

class Mq3Alcohol {
 public:
  void Begin(int adc_pin, int heater_en_pin) {
    pin_ = adc_pin;
    heater_pin_ = heater_en_pin;
    analogReadResolution(12);
    pinMode(pin_, INPUT);
    pinMode(heater_pin_, OUTPUT);
    SetHeater(false);
  }

  void SetHeater(bool on) {
    digitalWrite(heater_pin_, on ? HIGH : LOW);
    heater_on_ = on;
  }
  bool HeaterOn() const { return heater_on_; }

  int Read() const { return analogRead(pin_); }

 private:
  int pin_ = -1;
  int heater_pin_ = -1;
  bool heater_on_ = false;
};

}  // namespace helmet::sensors
