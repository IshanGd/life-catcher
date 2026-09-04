// Host tests for the Phase 3 alcohol pre-ride check-in (ADR-5) and the
// per-unit calibration routine it depends on. Every assertion here maps to
// 03_RULES.md §2 (never guess a per-unit threshold, never route this
// through the SOS path) or ADR-5 (gated pre-ride check, single sensor).
#include <unity.h>

#include "build_config.h"
#include "core/mq3_calibration.h"
#include "core/preride_check.h"

using helmet::core::AlcoholCalibration;
using helmet::core::Mq3CalibrationRoutine;
using helmet::core::PreRideCheckStateMachine;
using helmet::core::PreRideResult;
using helmet::schema::EventPayload;
using helmet::schema::EventType;
using helmet::schema::kSrcMq3;

void setUp() {}
void tearDown() {}

static AlcoholCalibration Calibrated(int baseline_adc) {
  AlcoholCalibration c;
  c.valid = true;
  c.baseline_adc = baseline_adc;
  return c;
}

// Drives a started state machine through warm-up and a full sampling
// window, feeding a constant reading throughout sampling.
static void RunToCompletion(PreRideCheckStateMachine& sm, int reading) {
  sm.Tick(cfg::mq3::kWarmupMs);
  for (uint32_t t = cfg::mq3::kWarmupMs;
       t <= cfg::mq3::kWarmupMs + cfg::mq3::kSampleWindowMs;
       t += cfg::mq3::kSampleIntervalMs) {
    sm.Feed(reading);
    sm.Tick(t);
  }
  sm.Tick(cfg::mq3::kWarmupMs + cfg::mq3::kSampleWindowMs);
}

void test_uncalibrated_unit_never_reports_pass_or_fail() {
  PreRideCheckStateMachine sm;
  AlcoholCalibration none;   // valid = false: no assembly-line baseline yet
  TEST_ASSERT_TRUE(sm.Start(none, 0));
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kUncalibrated),
                    static_cast<int>(sm.result()));
  EventPayload e;
  TEST_ASSERT_FALSE(sm.PopOutgoing(e));   // no alcohol_flag from an uncalibrated unit
}

void test_calibrated_unit_warms_up_before_sampling() {
  PreRideCheckStateMachine sm;
  sm.Start(Calibrated(1000), 0);
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kWarmingUp),
                    static_cast<int>(sm.result()));

  sm.Tick(cfg::mq3::kWarmupMs - 1);
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kWarmingUp),
                    static_cast<int>(sm.result()));

  sm.Tick(cfg::mq3::kWarmupMs);
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kSampling),
                    static_cast<int>(sm.result()));
}

void test_reading_fed_during_warmup_is_ignored() {
  PreRideCheckStateMachine sm;
  sm.Start(Calibrated(1000), 0);
  sm.Feed(4095);   // saturated reading during warm-up -- must not pollute the average
  RunToCompletion(sm, 1000);
  // If the saturated warm-up sample had counted, this would fail instead.
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kPassed),
                    static_cast<int>(sm.result()));
}

void test_reading_near_baseline_passes() {
  PreRideCheckStateMachine sm;
  sm.Start(Calibrated(1000), 0);
  RunToCompletion(sm, 1050);
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kPassed),
                    static_cast<int>(sm.result()));
  EventPayload e;
  TEST_ASSERT_FALSE(sm.PopOutgoing(e));   // a pass emits nothing
}

void test_reading_above_threshold_fails_and_emits_alcohol_flag() {
  PreRideCheckStateMachine sm;
  sm.Start(Calibrated(1000), 0);   // threshold = 1000 * kAlcoholRatioThreshold
  RunToCompletion(sm, 1800);
  TEST_ASSERT_EQUAL(static_cast<int>(PreRideResult::kFailed),
                    static_cast<int>(sm.result()));

  EventPayload e;
  TEST_ASSERT_TRUE(sm.PopOutgoing(e));
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kAlcoholFlag),
                    static_cast<int>(e.event_type));
  TEST_ASSERT_EQUAL(static_cast<int>(kSrcMq3), static_cast<int>(e.confirmed_by));
  // Not an SOS: no confirm/cancel lifecycle on this event (ADR-5).
  TEST_ASSERT_FALSE(e.awaiting_cancel);
  TEST_ASSERT_FALSE(e.confirmed);
  TEST_ASSERT_FALSE(e.cancelled);
}

void test_cannot_start_while_in_progress() {
  PreRideCheckStateMachine sm;
  TEST_ASSERT_TRUE(sm.Start(Calibrated(1000), 0));
  TEST_ASSERT_FALSE(sm.Start(Calibrated(1000), 100));
}

void test_heater_only_requested_while_in_progress() {
  PreRideCheckStateMachine sm;
  TEST_ASSERT_FALSE(sm.HeaterShouldBeOn());
  sm.Start(Calibrated(1000), 0);
  TEST_ASSERT_TRUE(sm.HeaterShouldBeOn());
  RunToCompletion(sm, 1050);
  TEST_ASSERT_FALSE(sm.HeaterShouldBeOn());   // done -- heater should be off again
}

void test_calibration_routine_produces_a_baseline() {
  Mq3CalibrationRoutine cal;
  TEST_ASSERT_TRUE(cal.Start(0));
  TEST_ASSERT_TRUE(cal.InProgress());

  cal.Tick(cfg::mq3::kWarmupMs);
  for (uint32_t t = cfg::mq3::kWarmupMs;
       t <= cfg::mq3::kWarmupMs + cfg::mq3::kSampleWindowMs;
       t += cfg::mq3::kSampleIntervalMs) {
    cal.Feed(900);
    cal.Tick(t);
  }
  cal.Tick(cfg::mq3::kWarmupMs + cfg::mq3::kSampleWindowMs);

  TEST_ASSERT_TRUE(cal.Done());
  AlcoholCalibration c = cal.Result(999999);
  TEST_ASSERT_TRUE(c.valid);
  TEST_ASSERT_EQUAL(900, c.baseline_adc);
  TEST_ASSERT_EQUAL_UINT32(999999, c.calibrated_at_ms);
}

void test_calibration_routine_rejects_a_zero_sample_run() {
  Mq3CalibrationRoutine cal;
  cal.Start(0);
  cal.Tick(cfg::mq3::kWarmupMs + cfg::mq3::kSampleWindowMs);   // done, but never Feed()
  TEST_ASSERT_TRUE(cal.Done());
  AlcoholCalibration c = cal.Result(0);
  TEST_ASSERT_FALSE(c.valid);   // never guess a threshold (03_RULES §2)
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_uncalibrated_unit_never_reports_pass_or_fail);
  RUN_TEST(test_calibrated_unit_warms_up_before_sampling);
  RUN_TEST(test_reading_fed_during_warmup_is_ignored);
  RUN_TEST(test_reading_near_baseline_passes);
  RUN_TEST(test_reading_above_threshold_fails_and_emits_alcohol_flag);
  RUN_TEST(test_cannot_start_while_in_progress);
  RUN_TEST(test_heater_only_requested_while_in_progress);
  RUN_TEST(test_calibration_routine_produces_a_baseline);
  RUN_TEST(test_calibration_routine_rejects_a_zero_sample_run);
  return UNITY_END();
}
