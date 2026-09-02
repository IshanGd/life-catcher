// SOS confirm/cancel state machine — the safety-critical core of the helmet.
//
// Governed by 03_RULES.md §1 & §2. Invariants this class enforces in code:
//
//  1. The cancel window is EXACTLY cfg::kSosCancelWindowMs. There is no
//     setter, no shorten path, and no "skip" method. (03_RULES §1)
//  2. A `crash_impact` SOS cannot start from a single sensor: Trigger()
//     rejects a crash whose `confirmed_by` names < 2 sources. (ADR-4)
//  3. Every SOS that starts emits an event; if it is cancelled, the
//     cancellation is ALSO emitted as an event (never silently dropped) so
//     fleets/insurers get real false-positive rates. (03_RULES §2)
//  4. An SOS in its window is always cancellable via Cancel(). (03_RULES §2)
//
// There is deliberately no ignition-control output anywhere in this class or
// the system it drives. (03_RULES §1)
//
// Framework-agnostic (time is passed in as `now_ms`); host-tested in
// test/test_sos_state_machine/.
#pragma once

#include <array>
#include <cstdint>

#include "build_config.h"
#include "core/ble_schema.h"

namespace helmet::core {

enum class SosState : uint8_t {
  kIdle,        // nothing pending
  kCountdown,   // an SOS fired; 10 s "are you OK?" window running; buzzer on
  kDispatched,  // window elapsed, not cancelled -> app should dispatch SOS
};

class SosStateMachine {
 public:
  using EventType   = helmet::schema::EventType;
  using EventPayload = helmet::schema::EventPayload;

  SosState state() const { return state_; }

  // Start an SOS. Returns false (and does nothing) if:
  //   - already in a countdown or dispatched state, or
  //   - `type` is kCrashImpact and `confirmed_by` is not fusion-confirmed
  //     (>= 2 distinct sources) -- ADR-4.
  // `type` kPanicButton is allowed with a single source (kSrcPanic): a person
  // pressing the button IS the decision, not a sensor inference.
  bool Trigger(EventType type, uint8_t confirmed_by, int severity_score,
               uint32_t now_ms);

  // Driver cancelled within the window. No-op unless state is kCountdown.
  // Emits a cancelled event (03_RULES §2). `reason` is copied.
  bool Cancel(uint32_t now_ms, const char* reason = "driver");

  // Advance time. When the countdown elapses with no cancel, transitions to
  // kDispatched and emits a confirmed event.
  void Tick(uint32_t now_ms);

  // The app / a human confirmed the dispatched SOS is handled; return to idle.
  void Acknowledge();

  // --- outputs ---------------------------------------------------------
  bool CancelPromptActive() const { return state_ == SosState::kCountdown; }
  uint32_t MillisRemaining(uint32_t now_ms) const;

  // Drain events to push over BLE. Returns false when empty.
  bool PopOutgoing(EventPayload& out);

  // Current pending event context (valid while not kIdle).
  EventType pending_type() const { return pending_.event_type; }
  int pending_severity() const { return pending_.severity_score; }

 private:
  void Enqueue(const EventPayload& e);

  SosState state_ = SosState::kIdle;
  EventPayload pending_{};        // the event that started this SOS
  uint32_t deadline_ms_ = 0;

  static constexpr size_t kQueueCap = 6;
  std::array<EventPayload, kQueueCap> queue_{};
  size_t q_head_ = 0, q_count_ = 0;
};

}  // namespace helmet::core
