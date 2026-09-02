// Panic / SOS button — personal-safety trigger (robbery/assault),
// 01_REQUIREMENTS.md §4.1. INDEPENDENT of crash-detection logic: a press
// arms an SOS directly (a human is the decision-maker), still through the
// standard cancel window unless a human decides otherwise (build_config.h,
// firmware/README.md).
#pragma once

#include "sensors/button.h"

namespace helmet::sensors {

class PanicButton {
 public:
  void Begin(int pin) { btn_.Begin(pin, /*active_low=*/true); }

  // true on the press edge.
  bool Pressed() { return btn_.Update(); }

  // A deliberate long-hold (>= ms) — useful if a future config wants
  // hold-to-arm instead of a single tap to reduce pocket presses.
  bool HeldFor(uint32_t ms) const { return btn_.held_ms() >= ms; }

 private:
  DebouncedButton btn_;
};

}  // namespace helmet::sensors
