// BLE GATT server (NimBLE). Relays the helmet's status + events to the
// companion app per the versioned contract in 02_ARCHITECTURE.md §4.
//
//   Service  6e40-0001-...   "Smart Helmet"
//     char   6e40-0002-...   STATUS   notify + read   (JSON StatusPayload)
//     char   6e40-0003-...   EVENT    notify + read   (JSON EventPayload)
//     char   6e40-0004-...   COMMAND  write           {"cmd":"cancel"|"ack"}
//
// The COMMAND char lets the app offer an on-screen cancel *in addition to*
// the physical button. It is still a driver-initiated cancel inside the
// window — it does not shorten or skip the window (03_RULES.md §1).
#pragma once

#include <functional>
#include <string>

#include "core/ble_schema.h"

namespace helmet::ble {

enum class AppCommand { kNone, kCancel, kAck };

class GattServer {
 public:
  void Begin(const char* device_name);

  void PublishStatus(const helmet::schema::StatusPayload& s);
  void PublishEvent(const helmet::schema::EventPayload& e);

  bool connected() const { return connected_; }
  uint32_t last_central_seen_ms() const { return last_seen_ms_; }

  // Poll for a command the app wrote since the last call.
  AppCommand TakeCommand();

  // internal (NimBLE callbacks)
  void OnConnectChange(bool up, uint32_t now_ms);
  void OnCommandWrite(const std::string& json, uint32_t now_ms);

 private:
  bool connected_ = false;
  uint32_t last_seen_ms_ = 0;
  AppCommand pending_cmd_ = AppCommand::kNone;
};

}  // namespace helmet::ble
