#include "core/sos_state_machine.h"

namespace helmet::core {

using helmet::schema::EventType;
using helmet::schema::IsFusionConfirmed;

bool SosStateMachine::Trigger(EventType type, uint8_t confirmed_by,
                              int severity_score, uint32_t now_ms) {
  if (state_ != SosState::kIdle) return false;

  // ADR-4 / 03_RULES §2: a crash SOS must be fusion-confirmed. Panic is a
  // deliberate human action and is exempt from the >=2-sensor rule.
  if (type == EventType::kCrashImpact && !IsFusionConfirmed(confirmed_by)) {
    return false;
  }
  if (type == EventType::kPanicButton && !cfg::kPanicUsesCancelWindow) {
    // Reserved for a future human decision (see build_config.h). Not enabled.
  }

  pending_ = EventPayload{};
  pending_.event_type          = type;
  pending_.severity_score      = severity_score;
  pending_.confirmed_by        = confirmed_by;
  pending_.timestamp_device_ms = now_ms;
  pending_.awaiting_cancel     = true;
  pending_.cancel_window_sec   =
      static_cast<int>(cfg::kSosCancelWindowMs / 1000);

  state_       = SosState::kCountdown;
  deadline_ms_ = now_ms + cfg::kSosCancelWindowMs;   // fixed, never shortened

  Enqueue(pending_);   // "SOS armed, awaiting cancel"
  return true;
}

bool SosStateMachine::Cancel(uint32_t now_ms, const char* reason) {
  if (state_ != SosState::kCountdown) return false;

  EventPayload e = pending_;
  e.awaiting_cancel     = false;
  e.cancelled           = true;
  e.confirmed           = false;
  e.timestamp_device_ms = now_ms;
  e.cancel_reason       = reason ? reason : "driver";
  Enqueue(e);          // 03_RULES §2: the cancellation is logged, not dropped

  state_ = SosState::kIdle;
  return true;
}

void SosStateMachine::Tick(uint32_t now_ms) {
  if (state_ != SosState::kCountdown) return;
  if (static_cast<int32_t>(now_ms - deadline_ms_) < 0) return;

  EventPayload e = pending_;
  e.awaiting_cancel     = false;
  e.cancelled           = false;
  e.confirmed           = true;
  e.timestamp_device_ms = now_ms;
  Enqueue(e);          // app dispatches SOS on this

  state_ = SosState::kDispatched;
}

void SosStateMachine::Acknowledge() {
  if (state_ == SosState::kDispatched) state_ = SosState::kIdle;
}

uint32_t SosStateMachine::MillisRemaining(uint32_t now_ms) const {
  if (state_ != SosState::kCountdown) return 0;
  int32_t rem = static_cast<int32_t>(deadline_ms_ - now_ms);
  return rem > 0 ? static_cast<uint32_t>(rem) : 0;
}

void SosStateMachine::Enqueue(const EventPayload& e) {
  if (q_count_ == kQueueCap) {
    // drop the OLDEST rather than the newest: a fresh confirmed/cancelled
    // event matters more than a stale "armed" notification.
    q_head_ = (q_head_ + 1) % kQueueCap;
    --q_count_;
  }
  queue_[(q_head_ + q_count_) % kQueueCap] = e;
  ++q_count_;
}

bool SosStateMachine::PopOutgoing(EventPayload& out) {
  if (q_count_ == 0) return false;
  out = queue_[q_head_];
  q_head_ = (q_head_ + 1) % kQueueCap;
  --q_count_;
  return true;
}

}  // namespace helmet::core
