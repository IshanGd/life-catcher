// Smart Helmet — Phase 2 prototype firmware entry point.
//
// Wires the sensors (src/sensors/) to the safety-critical core (src/core/)
// to the BLE relay (src/ble/). The core holds every rule-bound invariant
// (fusion-only crash, fixed 10 s cancel window, logged cancellations); this
// file is just plumbing and must stay that way.
//
// Bring-up order (04_PHASES.md Phase 2): panic button first, then buzzer +
// cancel, then MPU6050 + piezo fusion, then FSR, then BLE. All are enabled
// here; comment blocks out sensors you haven't wired yet.
#include <Arduino.h>

#include "ble/gatt_server.h"
#include "build_config.h"
#include "core/ble_schema.h"
#include "core/crash_fusion.h"
#include "core/imu_window.h"
#include "core/link_monitor.h"
#include "core/sos_state_machine.h"
#include "pins.h"
#include "sensors/buzzer.h"
#include "sensors/cancel_button.h"
#include "sensors/fsr_wear.h"
#include "sensors/imu_mpu6050.h"
#include "sensors/panic_button.h"
#include "sensors/piezo.h"

using namespace helmet;

namespace {

sensors::ImuMpu6050 g_imu;
sensors::Piezo      g_piezo;
sensors::FsrWear    g_fsr;
sensors::PanicButton g_panic;
sensors::CancelButton g_cancel;
sensors::Buzzer    g_buzzer;

core::ImuWindow        g_window;
core::SosStateMachine  g_sos;
core::LinkMonitor      g_link;
ble::GattServer        g_ble;

uint32_t g_last_status_ms = 0;
uint32_t g_last_event_pub_ms = 0;
uint32_t g_last_fusion_ms = 0;
bool     g_imu_ok = false;

int BatteryPct() {
  // Rough linear LiPo estimate from the divided VBAT node. Replace with a
  // real discharge curve once the battery is chosen (BOM, 01_REQUIREMENTS §5).
  // Return -1 until the divider is actually wired.
  constexpr bool kVbatWired = false;
  if (!kVbatWired) return -1;
  int raw = analogRead(PIN_VBAT_ADC);
  float v = (raw / 4095.0f) * 3.3f * VBAT_DIVIDER_RATIO;
  int pct = (int)((v - 3.3f) / (4.2f - 3.3f) * 100.0f);
  return pct < 0 ? 0 : (pct > 100 ? 100 : pct);
}

void PublishStatus(uint32_t now) {
  schema::StatusPayload s;
  s.helmet_worn     = g_fsr.Worn();
  s.pre_ride_passed = false;                 // Phase 3 (alcohol pre-ride gate)
  s.battery_pct     = BatteryPct();
  s.ble_link        = g_ble.connected();
  g_ble.PublishStatus(s);
  g_last_status_ms = now;
}

void DrainSosEvents() {
  schema::EventPayload e;
  while (g_sos.PopOutgoing(e)) {
    g_ble.PublishEvent(e);
    Serial.printf("[SOS] %s awaiting=%d cancelled=%d confirmed=%d sev=%d\n",
                  schema::ToString(e.event_type), e.awaiting_cancel,
                  e.cancelled, e.confirmed, e.severity_score);
  }
}

void UpdateBuzzer(uint32_t now) {
  using sensors::BuzzPattern;
  // priority: SOS confirm chirp handled inline; cancel prompt > link-lost
  if (g_sos.CancelPromptActive()) {
    g_buzzer.Set(BuzzPattern::kCancelPrompt, now);
  } else if (g_link.AlertActive()) {
    g_buzzer.Set(BuzzPattern::kLinkLost, now);
  } else if (g_buzzer.pattern() == BuzzPattern::kCancelPrompt ||
             g_buzzer.pattern() == BuzzPattern::kLinkLost) {
    g_buzzer.Set(BuzzPattern::kOff, now);
  }
  g_buzzer.Update(now);
  digitalWrite(PIN_LINK_LED, g_link.AlertActive() ? ((now / 200) % 2) : g_ble.connected());
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\nSmart Helmet " HELMET_FW_VERSION);

  pinMode(PIN_LINK_LED, OUTPUT);
  g_buzzer.Begin(PIN_BUZZER);
  g_panic.Begin(PIN_PANIC_BTN);
  g_cancel.Begin(PIN_CANCEL_BTN);
  g_piezo.Begin(PIN_PIEZO_ADC);
  g_fsr.Begin(PIN_FSR_ADC);

  g_imu_ok = g_imu.Begin(PIN_I2C_SDA, PIN_I2C_SCL, MPU6050_I2C_ADDR);
  Serial.printf("MPU6050: %s\n", g_imu_ok ? "ok" : "NOT FOUND");

  g_ble.Begin("SmartHelmet-0001");
  g_buzzer.Set(sensors::BuzzPattern::kSelfTest, millis());
  Serial.println("ready");
}

void loop() {
  const uint32_t now = millis();

  // --- sensor updates ------------------------------------------------
  g_piezo.Update(now);
  g_fsr.Update();

  core::ImuSample s;
  if (g_imu_ok && g_imu.Read(s, now)) g_window.Push(s);

  // --- buttons -----------------------------------------------------
  if (g_panic.Pressed()) {
    Serial.println("[BTN] panic");
    g_sos.Trigger(schema::EventType::kPanicButton, schema::kSrcPanic,
                  /*severity=*/90, now);
  }
  if (g_cancel.Pressed()) {
    Serial.println("[BTN] cancel");
    g_sos.Cancel(now, "driver");
  }

  // --- app commands over BLE -------------------------------------
  switch (g_ble.TakeCommand()) {
    case ble::AppCommand::kCancel: g_sos.Cancel(now, "driver_app"); break;
    case ble::AppCommand::kAck:    g_sos.Acknowledge();            break;
    default: break;
  }

  // --- fusion: once per window-worth of new data ------------------
  if ((now - g_last_fusion_ms) >= (uint32_t)(cfg::kImuWindowSeconds * 250) &&
      g_window.Full()) {
    g_last_fusion_ms = now;
    core::WindowFeatures f = g_window.Compute();
    bool piezo = g_piezo.ImpactSince(cfg::kFusionPairWindowMs, now);
    core::FusionResult r = core::Classify(f, piezo);

    if (r.is_emergency) {
      // ADR-4 enforced again inside Trigger(); a non-fused crash is rejected.
      g_sos.Trigger(r.event_type, r.confirmed_by, r.severity_score, now);
    } else if (r.event_type != schema::EventType::kNormalRiding &&
               (now - g_last_event_pub_ms) > 4000) {
      // non-emergency ride events for the app feed / scoring
      schema::EventPayload e;
      e.event_type = r.event_type;
      e.severity_score = r.severity_score;
      e.confirmed_by = r.confirmed_by;
      e.timestamp_device_ms = now;
      g_ble.PublishEvent(e);
      g_last_event_pub_ms = now;
      Serial.printf("[EVT] %s sev=%d\n", schema::ToString(r.event_type),
                    r.severity_score);
    }
  }

  // --- SOS timing + outputs ------------------------------------
  g_sos.Tick(now);
  DrainSosEvents();

  g_link.Update(g_ble.connected(), g_fsr.Worn(), now);
  UpdateBuzzer(now);

  if ((now - g_last_status_ms) >= cfg::kStatusNotifyIntervalMs) PublishStatus(now);
}
