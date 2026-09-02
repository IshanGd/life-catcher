// BLE-link-down indicator (01_REQUIREMENTS.md §4.1, §5; 03_RULES.md §2:
// "fail visibly, not silently"). If the phone link drops while the helmet is
// being worn, the driver must be told on the device itself — the whole
// phone-offload architecture (ADR-1) depends on the driver knowing when the
// safety layer has silently disconnected.
//
// Framework-agnostic; host-testable.
#pragma once

#include <cstdint>

#include "build_config.h"

namespace helmet::core {

class LinkMonitor {
 public:
  // `connected` = BLE central currently connected. `worn` = FSR says the
  // helmet is on (no point alarming a helmet sitting on a shelf).
  void Update(bool connected, bool worn, uint32_t now_ms) {
    worn_ = worn;
    if (connected) {
      last_ok_ms_ = now_ms;
      was_connected_ = true;
      degraded_ = false;
      return;
    }
    // Never connected yet -> not "degraded", just not-yet-paired.
    if (!was_connected_) return;
    degraded_ = worn_ && (now_ms - last_ok_ms_) >= cfg::kBleLinkTimeoutMs;
  }

  // True when the driver should be actively alerted (LED + buzzer).
  bool AlertActive() const { return degraded_; }

 private:
  bool worn_ = false;
  bool was_connected_ = false;
  bool degraded_ = false;
  uint32_t last_ok_ms_ = 0;
};

}  // namespace helmet::core
