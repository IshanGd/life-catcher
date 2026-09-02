// Host tests for the safety-critical SOS state machine.
// Every assertion here maps to a rule in 03_RULES.md §1/§2 or ADR-4.
#include <unity.h>

#include "build_config.h"
#include "core/sos_state_machine.h"

using helmet::core::SosState;
using helmet::core::SosStateMachine;
using helmet::schema::EventType;
using helmet::schema::EventPayload;
using helmet::schema::kSrcMpu6050;
using helmet::schema::kSrcPiezo;
using helmet::schema::kSrcPanic;

void setUp() {}
void tearDown() {}

static bool drain_last(SosStateMachine& sm, EventPayload& out) {
  bool got = false;
  EventPayload e;
  while (sm.PopOutgoing(e)) { out = e; got = true; }
  return got;
}

void test_starts_idle() {
  SosStateMachine sm;
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kIdle), static_cast<int>(sm.state()));
}

void test_fused_crash_starts_countdown_and_emits_armed_event() {
  SosStateMachine sm;
  bool ok = sm.Trigger(EventType::kCrashImpact, kSrcMpu6050 | kSrcPiezo, 80, 1000);
  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kCountdown), static_cast<int>(sm.state()));

  EventPayload e;
  TEST_ASSERT_TRUE(drain_last(sm, e));
  TEST_ASSERT_TRUE(e.awaiting_cancel);
  TEST_ASSERT_FALSE(e.cancelled);
  TEST_ASSERT_FALSE(e.confirmed);
  TEST_ASSERT_EQUAL(10, e.cancel_window_sec);
}

// ADR-4 / 03_RULES §2: a crash SOS may not start from a single sensor.
void test_single_sensor_crash_is_rejected() {
  SosStateMachine sm;
  bool ok = sm.Trigger(EventType::kCrashImpact, kSrcMpu6050, 95, 1000);
  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kIdle), static_cast<int>(sm.state()));
  EventPayload e;
  TEST_ASSERT_FALSE(sm.PopOutgoing(e));   // nothing emitted
}

// Panic is a deliberate human action, exempt from the >=2-sensor rule.
void test_panic_single_source_is_accepted() {
  SosStateMachine sm;
  TEST_ASSERT_TRUE(sm.Trigger(EventType::kPanicButton, kSrcPanic, 90, 500));
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kCountdown), static_cast<int>(sm.state()));
}

// 03_RULES §1: the cancel window is exactly kSosCancelWindowMs.
void test_cancel_window_is_exactly_ten_seconds() {
  SosStateMachine sm;
  sm.Trigger(EventType::kPanicButton, kSrcPanic, 90, 0);
  TEST_ASSERT_EQUAL_UINT32(cfg::kSosCancelWindowMs, sm.MillisRemaining(0));

  sm.Tick(cfg::kSosCancelWindowMs - 1);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kCountdown), static_cast<int>(sm.state()));
  TEST_ASSERT_EQUAL_UINT32(1, sm.MillisRemaining(cfg::kSosCancelWindowMs - 1));

  sm.Tick(cfg::kSosCancelWindowMs);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kDispatched), static_cast<int>(sm.state()));
}

// 03_RULES §2: cancellation is itself logged as an event, never dropped.
void test_cancel_emits_a_logged_cancelled_event() {
  SosStateMachine sm;
  sm.Trigger(EventType::kCrashImpact, kSrcMpu6050 | kSrcPiezo, 70, 1000);
  EventPayload armed;
  drain_last(sm, armed);

  bool ok = sm.Cancel(4000, "driver");
  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kIdle), static_cast<int>(sm.state()));

  EventPayload e;
  TEST_ASSERT_TRUE(drain_last(sm, e));
  TEST_ASSERT_TRUE(e.cancelled);
  TEST_ASSERT_FALSE(e.confirmed);
  TEST_ASSERT_FALSE(e.awaiting_cancel);
  TEST_ASSERT_EQUAL_STRING("driver", e.cancel_reason.c_str());
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kCrashImpact),
                    static_cast<int>(e.event_type));
}

void test_timeout_emits_confirmed_event_for_app_dispatch() {
  SosStateMachine sm;
  sm.Trigger(EventType::kCrashImpact, kSrcMpu6050 | kSrcPiezo, 88, 0);
  EventPayload armed; drain_last(sm, armed);

  sm.Tick(cfg::kSosCancelWindowMs + 5);
  EventPayload e;
  TEST_ASSERT_TRUE(drain_last(sm, e));
  TEST_ASSERT_TRUE(e.confirmed);
  TEST_ASSERT_FALSE(e.cancelled);
  TEST_ASSERT_FALSE(e.awaiting_cancel);
}

// A cancel arriving after the window closed must not un-dispatch the SOS.
void test_cancel_after_dispatch_is_noop() {
  SosStateMachine sm;
  sm.Trigger(EventType::kPanicButton, kSrcPanic, 90, 0);
  sm.Tick(cfg::kSosCancelWindowMs + 1);
  EventPayload junk; drain_last(sm, junk);

  bool ok = sm.Cancel(cfg::kSosCancelWindowMs + 50, "driver");
  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kDispatched), static_cast<int>(sm.state()));
  EventPayload e;
  TEST_ASSERT_FALSE(sm.PopOutgoing(e));
}

void test_retrigger_during_countdown_is_ignored() {
  SosStateMachine sm;
  sm.Trigger(EventType::kCrashImpact, kSrcMpu6050 | kSrcPiezo, 50, 1000);
  bool second = sm.Trigger(EventType::kCrashImpact, kSrcMpu6050 | kSrcPiezo, 99, 1200);
  TEST_ASSERT_FALSE(second);
  TEST_ASSERT_EQUAL(50, sm.pending_severity());   // unchanged
}

void test_acknowledge_returns_to_idle_after_dispatch() {
  SosStateMachine sm;
  sm.Trigger(EventType::kPanicButton, kSrcPanic, 90, 0);
  sm.Tick(cfg::kSosCancelWindowMs + 1);
  sm.Acknowledge();
  TEST_ASSERT_EQUAL(static_cast<int>(SosState::kIdle), static_cast<int>(sm.state()));
  // ready to arm again
  TEST_ASSERT_TRUE(sm.Trigger(EventType::kPanicButton, kSrcPanic, 90, 20000));
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_starts_idle);
  RUN_TEST(test_fused_crash_starts_countdown_and_emits_armed_event);
  RUN_TEST(test_single_sensor_crash_is_rejected);
  RUN_TEST(test_panic_single_source_is_accepted);
  RUN_TEST(test_cancel_window_is_exactly_ten_seconds);
  RUN_TEST(test_cancel_emits_a_logged_cancelled_event);
  RUN_TEST(test_timeout_emits_confirmed_event_for_app_dispatch);
  RUN_TEST(test_cancel_after_dispatch_is_noop);
  RUN_TEST(test_retrigger_during_countdown_is_ignored);
  RUN_TEST(test_acknowledge_returns_to_idle_after_dispatch);
  return UNITY_END();
}
