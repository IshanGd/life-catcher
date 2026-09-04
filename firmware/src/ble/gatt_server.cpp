#include "ble/gatt_server.h"

#include <Arduino.h>
#include <NimBLEDevice.h>

namespace helmet::ble {

namespace {
constexpr char kSvcUuid[]    = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
constexpr char kStatusUuid[] = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
constexpr char kEventUuid[]  = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
constexpr char kCmdUuid[]    = "6e400004-b5a3-f393-e0a9-e50e24dcca9e";

NimBLECharacteristic* g_status = nullptr;
NimBLECharacteristic* g_event  = nullptr;
GattServer* g_owner = nullptr;

// NOTE: callback signatures below target NimBLE-Arduino 1.4.x (the version
// that pairs with arduino-esp32 2.0.x / espressif32 6.x — see platformio.ini).
// NimBLE 2.x changed these to take a NimBLEConnInfo&; if you bump the library,
// update these three overrides.
class ServerCb : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*) override {
    if (g_owner) g_owner->OnConnectChange(true, millis());
  }
  void onDisconnect(NimBLEServer*) override {
    if (g_owner) g_owner->OnConnectChange(false, millis());
    NimBLEDevice::startAdvertising();
  }
};

class CmdCb : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c) override {
    if (g_owner) g_owner->OnCommandWrite(std::string(c->getValue().c_str()), millis());
  }
};

ServerCb g_server_cb;
CmdCb    g_cmd_cb;
}  // namespace

void GattServer::Begin(const char* device_name) {
  g_owner = this;
  NimBLEDevice::init(device_name);
  // (TX power left at the stack default for bring-up; NimBLE's setPower
  //  signature differs across 1.x/2.x — set it once the library is pinned.)

  NimBLEServer* server = NimBLEDevice::createServer();
  server->setCallbacks(&g_server_cb);

  NimBLEService* svc = server->createService(kSvcUuid);
  g_status = svc->createCharacteristic(
      kStatusUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  g_event = svc->createCharacteristic(
      kEventUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  NimBLECharacteristic* cmd = svc->createCharacteristic(
      kCmdUuid, NIMBLE_PROPERTY::WRITE);
  cmd->setCallbacks(&g_cmd_cb);

  svc->start();

  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(kSvcUuid);
  adv->setScanResponse(true);
  NimBLEDevice::startAdvertising();
  (void)device_name;  // advertised name is set via NimBLEDevice::init()
}

void GattServer::PublishStatus(const helmet::schema::StatusPayload& s) {
  if (!g_status) return;
  std::string j = helmet::schema::Serialize(s);
  g_status->setValue(reinterpret_cast<const uint8_t*>(j.data()), j.size());
  if (connected_) g_status->notify();
}

void GattServer::PublishEvent(const helmet::schema::EventPayload& e) {
  if (!g_event) return;
  std::string j = helmet::schema::Serialize(e);
  g_event->setValue(reinterpret_cast<const uint8_t*>(j.data()), j.size());
  if (connected_) g_event->notify();
}

AppCommand GattServer::TakeCommand() {
  AppCommand c = pending_cmd_;
  pending_cmd_ = AppCommand::kNone;
  return c;
}

void GattServer::OnConnectChange(bool up, uint32_t now_ms) {
  connected_ = up;
  last_seen_ms_ = now_ms;
}

void GattServer::OnCommandWrite(const std::string& json, uint32_t now_ms) {
  last_seen_ms_ = now_ms;
  if (json.find("\"cancel\"") != std::string::npos)   pending_cmd_ = AppCommand::kCancel;
  else if (json.find("\"ack\"") != std::string::npos) pending_cmd_ = AppCommand::kAck;
  else if (json.find("\"start_check\"") != std::string::npos)
    pending_cmd_ = AppCommand::kStartPreRideCheck;
}

}  // namespace helmet::ble
