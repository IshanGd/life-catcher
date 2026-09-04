// Shared "warm up, then average N ms of ADC readings" primitive used by
// both the live pre-ride check (core/preride_check.h) and the per-unit
// calibration routine (core/mq3_calibration.h) -- the two places that need
// the exact same MQ-3 warm-up + averaging behaviour.
//
// Framework-agnostic; time is passed in as `now_ms`.
#pragma once

#include <cstdint>

namespace helmet::core {

class WarmupAverager {
 public:
  void Start(uint32_t now_ms, uint32_t warmup_ms, uint32_t sample_window_ms) {
    warm_done_ms_ = now_ms + warmup_ms;
    window_ms_ = sample_window_ms;
    sum_ = 0;
    count_ = 0;
    warming_ = true;
    done_ = false;
  }

  void Tick(uint32_t now_ms) {
    if (done_) return;
    if (warming_ && now_ms >= warm_done_ms_) warming_ = false;
    if (!warming_ && (now_ms - warm_done_ms_) >= window_ms_) done_ = true;
  }

  // Ignored while warming up or once done -- only counts inside the window.
  void Feed(int raw_adc) {
    if (warming_ || done_) return;
    sum_ += raw_adc;
    ++count_;
  }

  bool warming() const { return warming_; }
  bool done() const { return done_; }
  int  sample_count() const { return count_; }
  int  average() const { return count_ > 0 ? static_cast<int>(sum_ / count_) : 0; }

 private:
  long sum_ = 0;
  int  count_ = 0;
  uint32_t warm_done_ms_ = 0;
  uint32_t window_ms_ = 0;
  bool warming_ = true;
  bool done_ = false;
};

}  // namespace helmet::core
