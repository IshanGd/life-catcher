// Buzzer — two jobs (01_REQUIREMENTS.md §4.1):
//   1. the audible "are you OK?" prompt during the SOS cancel window
//   2. fail-visibly alert when the BLE link to the phone drops (03_RULES §2)
// Non-blocking: call Update(now) every loop.
#pragma once

#include <Arduino.h>

namespace helmet::sensors {

enum class BuzzPattern : uint8_t {
  kOff,
  kCancelPrompt,   // urgent: 4 Hz on/off while the cancel window runs
  kLinkLost,       // distinct: double-beep every 2 s
  kConfirmed,      // solid 1 s, then off (SOS dispatched)
  kSelfTest,       // single 150 ms chirp
};

class Buzzer {
 public:
  void Begin(int pin) {
    pin_ = pin;
    pinMode(pin_, OUTPUT);
    digitalWrite(pin_, LOW);
  }

  void Set(BuzzPattern p, uint32_t now_ms) {
    if (p == pattern_) return;
    pattern_ = p;
    phase_start_ms_ = now_ms;
    ApplyLevel(false);
  }

  void Update(uint32_t now_ms) {
    uint32_t t = now_ms - phase_start_ms_;
    switch (pattern_) {
      case BuzzPattern::kOff:
        ApplyLevel(false);
        break;
      case BuzzPattern::kCancelPrompt:
        ApplyLevel((t / 125) % 2 == 0);           // 4 Hz
        break;
      case BuzzPattern::kLinkLost:
        ApplyLevel(t % 2000 < 80 || (t % 2000 >= 160 && t % 2000 < 240));
        break;
      case BuzzPattern::kConfirmed:
        if (t < 1000) ApplyLevel(true);
        else { ApplyLevel(false); pattern_ = BuzzPattern::kOff; }
        break;
      case BuzzPattern::kSelfTest:
        if (t < 150) ApplyLevel(true);
        else { ApplyLevel(false); pattern_ = BuzzPattern::kOff; }
        break;
    }
  }

  BuzzPattern pattern() const { return pattern_; }

 private:
  void ApplyLevel(bool on) {
    if (on == on_) return;
    on_ = on;
    digitalWrite(pin_, on ? HIGH : LOW);
  }

  int pin_ = -1;
  BuzzPattern pattern_ = BuzzPattern::kOff;
  uint32_t phase_start_ms_ = 0;
  bool on_ = false;
};

}  // namespace helmet::sensors
