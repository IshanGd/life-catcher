// Pin map for the Phase 2 prototype (generic ESP32 DevKit v1, 30-pin).
// Adjust to your board / wiring and keep firmware/docs/WIRING.md in sync.
//
// Rules this file must respect (03_RULES.md):
//  - one sensor per driver file under src/sensors/, mirroring 01_REQUIREMENTS
//    §4.1: MPU6050, piezo, FSR, panic button, buzzer (+ cancel button).
//  - NOTHING here may drive a vehicle-ignition line. There is no such pin,
//    by design, and there must never be one.
#pragma once

// --- I2C: MPU6050 (accel + gyro) -----------------------------------------
static constexpr int PIN_I2C_SDA = 21;
static constexpr int PIN_I2C_SCL = 22;
static constexpr int MPU6050_I2C_ADDR = 0x68;   // AD0 low; 0x69 if AD0 high
static constexpr int PIN_MPU_INT = 4;           // MPU6050 INT (optional, data-ready)

// --- Piezo impact sensor (analog, through a divider + clamp) -------------
// ADC1 channel so it keeps working with Wi-Fi/BLE radio active.
static constexpr int PIN_PIEZO_ADC = 34;        // input-only, ADC1_CH6

// --- FSR wear detection (analog voltage divider) ------------------------
static constexpr int PIN_FSR_ADC = 35;          // input-only, ADC1_CH7

// --- Panic / SOS button (independent of crash logic, 01_REQUIREMENTS §4.1)
// Wired to GND, INPUT_PULLUP -> pressed == LOW.
static constexpr int PIN_PANIC_BTN = 25;

// --- Cancel / confirm button (the 10 s "are you OK?" window) ------------
static constexpr int PIN_CANCEL_BTN = 26;

// --- Buzzer (cancel/confirm prompt + fail-visibly link-down alert) ------
static constexpr int PIN_BUZZER = 27;           // active buzzer or LEDC PWM

// --- Status LED (BLE link state; fail visibly, not silently) -----------
static constexpr int PIN_LINK_LED = 2;          // onboard LED on most DevKits

// --- Battery sense (divider from VBAT); optional on first bring-up -----
static constexpr int PIN_VBAT_ADC = 32;         // ADC1_CH4
static constexpr float VBAT_DIVIDER_RATIO = 2.0f;

// --- MQ-3 alcohol sensor (Phase 3, gated pre-ride check only, ADR-5) ----
// Analog output straight into an ADC1 pin (the module has its own onboard
// load resistor). The heater (~150 mA) is switched by a transistor under
// GPIO control so it draws nothing between checks -- an ESP32 GPIO can't
// source that much current directly. See firmware/docs/WIRING.md.
static constexpr int PIN_MQ3_ADC       = 36;    // input-only, ADC1_CH0 (SVP)
static constexpr int PIN_MQ3_HEATER_EN = 23;    // drives heater switch transistor
