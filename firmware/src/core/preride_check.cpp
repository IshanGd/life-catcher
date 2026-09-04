#include "core/preride_check.h"

namespace helmet::core {

bool PreRideCheckStateMachine::Start(const AlcoholCalibration& calib, uint32_t now_ms) {
  if (InProgress()) return false;
  calib_ = calib;
  last_average_adc_ = 0;
  has_outgoing_ = false;

  if (!calib_.valid) {
    result_ = PreRideResult::kUncalibrated;  // report unknown, never a silent pass
    return true;
  }
  averager_.Start(now_ms, cfg::mq3::kWarmupMs, cfg::mq3::kSampleWindowMs);
  result_ = PreRideResult::kWarmingUp;
  return true;
}

void PreRideCheckStateMachine::Feed(int raw_adc) {
  if (!InProgress()) return;
  averager_.Feed(raw_adc);
}

void PreRideCheckStateMachine::Tick(uint32_t now_ms) {
  if (!InProgress()) return;

  averager_.Tick(now_ms);
  result_ = averager_.warming() ? PreRideResult::kWarmingUp : PreRideResult::kSampling;
  if (!averager_.done()) return;

  if (averager_.sample_count() == 0) {
    result_ = PreRideResult::kUncalibrated;  // sensor gave nothing -- report unknown, not a pass
    return;
  }

  last_average_adc_ = averager_.average();
  float threshold = calib_.baseline_adc * cfg::mq3::kAlcoholRatioThreshold;
  bool failed = last_average_adc_ >= threshold;
  result_ = failed ? PreRideResult::kFailed : PreRideResult::kPassed;

  if (failed) {
    EventPayload e;
    e.event_type = helmet::schema::EventType::kAlcoholFlag;
    e.confirmed_by = helmet::schema::kSrcMq3;
    e.timestamp_device_ms = now_ms;
    // Single-shot flag, no confirm/cancel lifecycle -- this is a screening
    // gate, not an SOS (ADR-5); never routed through SosStateMachine.
    outgoing_ = e;
    has_outgoing_ = true;
  }
}

bool PreRideCheckStateMachine::PopOutgoing(EventPayload& out) {
  if (!has_outgoing_) return false;
  out = outgoing_;
  has_outgoing_ = false;
  return true;
}

}  // namespace helmet::core
