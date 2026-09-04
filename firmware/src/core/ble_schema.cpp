#include "core/ble_schema.h"

#include <ArduinoJson.h>

namespace helmet::schema {

const char* ToString(EventType t) {
  switch (t) {
    case EventType::kNormalRiding: return "normal_riding";
    case EventType::kPotholeBump:  return "pothole_bump";
    case EventType::kHarshBrake:   return "harsh_brake";
    case EventType::kCrashImpact:  return "crash_impact";
    case EventType::kPanicButton:  return "panic_button";
    case EventType::kAlcoholFlag:  return "alcohol_flag";
  }
  return "normal_riding";
}

bool IsFusionConfirmed(uint8_t confirmed_by) {
  int n = 0;
  for (uint8_t b = confirmed_by; b; b &= (b - 1)) ++n;
  return n >= 2;
}

static void AddSources(JsonArray arr, uint8_t bits) {
  if (bits & kSrcMpu6050) arr.add("mpu6050");
  if (bits & kSrcPiezo)   arr.add("piezo");
  if (bits & kSrcFsr)     arr.add("fsr");
  if (bits & kSrcPanic)   arr.add("panic_button");
  if (bits & kSrcMq3)     arr.add("mq3");
}

std::string Serialize(const StatusPayload& s) {
  JsonDocument doc;
  doc["schema"]          = kSchemaVersion;
  doc["helmet_worn"]     = s.helmet_worn;
  doc["pre_ride_passed"] = s.pre_ride_passed;
  if (s.battery_pct >= 0) doc["battery_pct"] = s.battery_pct;
  else                    doc["battery_pct"] = nullptr;
  doc["firmware"]        = s.firmware;
  doc["ble_link"]        = s.ble_link;
  doc["event"]           = nullptr;   // events go on the EVENT characteristic
  char buf[256];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  return std::string(buf, n);
}

std::string Serialize(const EventPayload& e) {
  JsonDocument doc;
  doc["schema"]              = kSchemaVersion;
  doc["event_type"]          = ToString(e.event_type);
  doc["severity_score"]      = e.severity_score;
  AddSources(doc["confirmed_by"].to<JsonArray>(), e.confirmed_by);
  doc["timestamp_device_ms"] = e.timestamp_device_ms;
  doc["awaiting_cancel"]     = e.awaiting_cancel;
  doc["cancel_window_sec"]   = e.cancel_window_sec;
  doc["cancelled"]           = e.cancelled;
  doc["confirmed"]           = e.confirmed;
  if (!e.cancel_reason.empty()) doc["cancel_reason"] = e.cancel_reason.c_str();
  char buf[320];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  return std::string(buf, n);
}

}  // namespace helmet::schema
