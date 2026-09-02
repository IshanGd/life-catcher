// Host tests for the BLE JSON contract (02_ARCHITECTURE.md §4).
#include <unity.h>

#include <string>

#include "core/ble_schema.h"

using namespace helmet::schema;

void setUp() {}
void tearDown() {}

static bool has(const std::string& s, const char* sub) {
  return s.find(sub) != std::string::npos;
}

void test_status_payload_shape() {
  StatusPayload s;
  s.helmet_worn = true;
  s.pre_ride_passed = false;
  s.battery_pct = 78;
  s.ble_link = true;
  std::string j = Serialize(s);

  TEST_ASSERT_TRUE(has(j, "\"schema\":1"));
  TEST_ASSERT_TRUE(has(j, "\"helmet_worn\":true"));
  TEST_ASSERT_TRUE(has(j, "\"pre_ride_passed\":false"));
  TEST_ASSERT_TRUE(has(j, "\"battery_pct\":78"));
  TEST_ASSERT_TRUE(has(j, "\"ble_link\":true"));
  TEST_ASSERT_TRUE(has(j, "\"event\":null"));
}

void test_unknown_battery_serialises_null() {
  StatusPayload s;               // battery_pct defaults to -1
  std::string j = Serialize(s);
  TEST_ASSERT_TRUE(has(j, "\"battery_pct\":null"));
}

void test_event_type_strings_match_ml_label_set() {
  TEST_ASSERT_EQUAL_STRING("normal_riding", ToString(EventType::kNormalRiding));
  TEST_ASSERT_EQUAL_STRING("pothole_bump",  ToString(EventType::kPotholeBump));
  TEST_ASSERT_EQUAL_STRING("harsh_brake",   ToString(EventType::kHarshBrake));
  TEST_ASSERT_EQUAL_STRING("crash_impact",  ToString(EventType::kCrashImpact));
  TEST_ASSERT_EQUAL_STRING("panic_button",  ToString(EventType::kPanicButton));
  TEST_ASSERT_EQUAL_STRING("alcohol_flag",  ToString(EventType::kAlcoholFlag));
}

void test_crash_event_lists_both_sensors() {
  EventPayload e;
  e.event_type = EventType::kCrashImpact;
  e.severity_score = 84;
  e.confirmed_by = static_cast<uint8_t>(kSrcMpu6050 | kSrcPiezo);
  e.timestamp_device_ms = 1234567;
  e.awaiting_cancel = true;
  e.cancel_window_sec = 10;
  std::string j = Serialize(e);

  TEST_ASSERT_TRUE(has(j, "\"event_type\":\"crash_impact\""));
  TEST_ASSERT_TRUE(has(j, "\"confirmed_by\":[\"mpu6050\",\"piezo\"]"));
  TEST_ASSERT_TRUE(has(j, "\"awaiting_cancel\":true"));
  TEST_ASSERT_TRUE(has(j, "\"cancel_window_sec\":10"));
  TEST_ASSERT_TRUE(has(j, "\"timestamp_device_ms\":1234567"));
}

void test_fusion_confirmed_predicate() {
  TEST_ASSERT_FALSE(IsFusionConfirmed(kSrcNone));
  TEST_ASSERT_FALSE(IsFusionConfirmed(kSrcMpu6050));
  TEST_ASSERT_TRUE(IsFusionConfirmed(kSrcMpu6050 | kSrcPiezo));
  TEST_ASSERT_TRUE(IsFusionConfirmed(kSrcMpu6050 | kSrcPiezo | kSrcFsr));
}

void test_cancelled_event_carries_reason() {
  EventPayload e;
  e.event_type = EventType::kCrashImpact;
  e.cancelled = true;
  e.cancel_reason = "driver";
  std::string j = Serialize(e);
  TEST_ASSERT_TRUE(has(j, "\"cancelled\":true"));
  TEST_ASSERT_TRUE(has(j, "\"cancel_reason\":\"driver\""));
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_status_payload_shape);
  RUN_TEST(test_unknown_battery_serialises_null);
  RUN_TEST(test_event_type_strings_match_ml_label_set);
  RUN_TEST(test_crash_event_lists_both_sensors);
  RUN_TEST(test_fusion_confirmed_predicate);
  RUN_TEST(test_cancelled_event_carries_reason);
  return UNITY_END();
}
