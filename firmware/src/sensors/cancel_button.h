// Cancel / confirm button — the driver's way to stop a false SOS inside the
// 10-second window (01_REQUIREMENTS.md §4.1, 03_RULES.md §1/§2).
#pragma once

#include "sensors/button.h"

namespace helmet::sensors {

class CancelButton {
 public:
  void Begin(int pin) { btn_.Begin(pin, /*active_low=*/true); }
  bool Pressed() { return btn_.Update(); }

 private:
  DebouncedButton btn_;
};

}  // namespace helmet::sensors
