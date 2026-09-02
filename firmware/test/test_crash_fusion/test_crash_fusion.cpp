// Host tests for the provisional fusion classifier.
// Focus: ADR-4 (no single-sensor crash) and the crash-vs-pothole /
// crash-vs-braking separation the DAMOTO analysis showed matters.
#include <unity.h>

#include "core/crash_fusion.h"
#include "core/imu_window.h"

using helmet::core::Classify;
using helmet::core::FusionResult;
using helmet::core::WindowFeatures;
using helmet::schema::EventType;

void setUp() {}
void tearDown() {}

// A crash-shaped window: big impact + settled, tipped-over aftermath.
static WindowFeatures CrashLike() {
  WindowFeatures f;
  f.full = true;
  f.amag_max = 5.0f;
  f.jerk_absmax = 120.0f;
  f.g_recovery_ratio = 0.03f;             // gyro dead after the hit
  f.ay_second_half_mean = -0.95f;         // gravity now on ay: bike on its side
  f.az_second_half_mean = 0.1f;
  f.ax_mean = 0.2f;
  return f;
}

void test_crash_needs_both_sensors() {
  WindowFeatures f = CrashLike();

  FusionResult without = Classify(f, /*piezo_confirmed=*/false);
  TEST_ASSERT_FALSE(without.is_emergency);
  TEST_ASSERT_NOT_EQUAL(static_cast<int>(EventType::kCrashImpact),
                        static_cast<int>(without.event_type));

  FusionResult with = Classify(f, /*piezo_confirmed=*/true);
  TEST_ASSERT_TRUE(with.is_emergency);
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kCrashImpact),
                    static_cast<int>(with.event_type));
  TEST_ASSERT_TRUE(helmet::schema::IsFusionConfirmed(with.confirmed_by));
  TEST_ASSERT_TRUE(with.severity_score > 0);
}

// Pothole: sharp spike, but the bike recovers — no sustained tilt. Even with
// a piezo hit this must NOT be an emergency.
void test_pothole_spike_with_piezo_is_not_a_crash() {
  WindowFeatures f;
  f.full = true;
  f.amag_max = 3.0f;
  f.jerk_absmax = 90.0f;
  f.g_recovery_ratio = 0.9f;              // recovered
  f.ay_second_half_mean = 0.0f;
  f.az_second_half_mean = -1.0f;          // still upright
  f.ax_mean = 0.0f;

  FusionResult r = Classify(f, /*piezo_confirmed=*/true);
  TEST_ASSERT_FALSE(r.is_emergency);
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kPotholeBump),
                    static_cast<int>(r.event_type));
}

void test_harsh_braking_is_flagged_non_emergency() {
  WindowFeatures f;
  f.full = true;
  f.amag_max = 1.3f;
  f.jerk_absmax = 15.0f;
  f.ax_mean = -0.6f;                      // sustained forward decel
  f.g_recovery_ratio = 1.8f;              // disturbance ramps up
  f.az_second_half_mean = -1.0f;

  FusionResult r = Classify(f, false);
  TEST_ASSERT_FALSE(r.is_emergency);
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kHarshBrake),
                    static_cast<int>(r.event_type));
}

void test_calm_riding_is_normal() {
  WindowFeatures f;
  f.full = true;
  f.amag_max = 1.05f;
  f.jerk_absmax = 4.0f;
  f.ax_mean = 0.02f;
  f.g_recovery_ratio = 1.0f;
  f.az_second_half_mean = -1.0f;

  FusionResult r = Classify(f, false);
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kNormalRiding),
                    static_cast<int>(r.event_type));
}

void test_incomplete_window_decides_nothing() {
  WindowFeatures f = CrashLike();
  f.full = false;
  FusionResult r = Classify(f, true);
  TEST_ASSERT_FALSE(r.is_emergency);
  TEST_ASSERT_EQUAL(static_cast<int>(EventType::kNormalRiding),
                    static_cast<int>(r.event_type));
}

// Feed the ImuWindow raw samples and confirm the features come out sane.
void test_imu_window_features_roundtrip() {
  helmet::core::ImuWindow w;
  for (int i = 0; i < 100; ++i) {
    helmet::core::ImuSample s{0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 0.0f};
    if (i == 20) { s.az = -5.0f; }           // one spike
    if (i >= 55) { s.ay = -0.9f; s.az = 0.0f; }  // tipped over, second half
    w.Push(s);
  }
  TEST_ASSERT_TRUE(w.Full());
  auto f = w.Compute();
  TEST_ASSERT_TRUE(f.full);
  TEST_ASSERT_TRUE(f.amag_max > 4.0f);
  TEST_ASSERT_TRUE(f.ay_second_half_mean < -0.5f);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_crash_needs_both_sensors);
  RUN_TEST(test_pothole_spike_with_piezo_is_not_a_crash);
  RUN_TEST(test_harsh_braking_is_flagged_non_emergency);
  RUN_TEST(test_calm_riding_is_normal);
  RUN_TEST(test_incomplete_window_decides_nothing);
  RUN_TEST(test_imu_window_features_roundtrip);
  return UNITY_END();
}
