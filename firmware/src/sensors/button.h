// Shared debounce for the two physical buttons (panic, cancel). Not a sensor
// itself — the panic and cancel buttons each get their own driver file
// (03_RULES.md §4) and use this.
#pragma once

#include <Arduino.h>

namespace helmet::sensors {

class DebouncedButton {
 public:
  // `active_low` true for INPUT_PULLUP wiring to GND (pressed == LOW).
  void Begin(int pin, bool active_low = true, uint16_t debounce_ms = 25) {
    pin_ = pin;
    active_low_ = active_low;
    debounce_ms_ = debounce_ms;
    pinMode(pin_, active_low_ ? INPUT_PULLUP : INPUT);
    raw_ = stable_ = Read();
    last_change_ms_ = millis();
  }

  // Call every loop. Returns true on the press edge (release-to-press).
  bool Update() {
    bool r = Read();
    uint32_t now = millis();
    if (r != raw_) { raw_ = r; last_change_ms_ = now; }
    bool edge = false;
    if ((now - last_change_ms_) >= debounce_ms_ && r != stable_) {
      stable_ = r;
      edge = stable_;         // edge only on the transition into "pressed"
    }
    return edge;
  }

  bool held() const { return stable_; }
  uint32_t held_ms() const { return stable_ ? (millis() - last_change_ms_) : 0; }

 private:
  bool Read() const {
    int v = digitalRead(pin_);
    return active_low_ ? (v == LOW) : (v == HIGH);
  }

  int pin_ = -1;
  bool active_low_ = true;
  uint16_t debounce_ms_ = 25;
  bool raw_ = false, stable_ = false;
  uint32_t last_change_ms_ = 0;
};

}  // namespace helmet::sensors
