# Phase 2 prototype — wiring

**Diagrams:** [`wiring-pictorial.svg`](wiring-pictorial.svg) (assembly view —
component illustrations + colour-coded wires) and
[`wiring-diagram.svg`](wiring-diagram.svg) (exact-net schematic reference).
**Parts list + full assembly walkthrough:** [`BOM.md`](BOM.md).
This file is the quick pin reference.

![Pictorial wiring — assembly view](wiring-pictorial.svg)

![Schematic wiring — exact-net reference](wiring-diagram.svg)

Reference board: **generic ESP32 DevKit v1 (30-pin)**. Pin numbers are GPIO
numbers and live in [`../include/pins.h`](../include/pins.h) — edit there if
your board differs, keep this table in sync.

Sensors match the hardware table in `01_REQUIREMENTS.md` §4.1. This build
includes the MQ-3 alcohol sensor (Phase 3) alongside the Phase 2 sensors —
the bare module only; the breath-sampling chamber (mouthpiece / hygiene)
is a separate, still-open physical-design question and is not needed for
bench bring-up. See §"Alcohol pre-ride check" below.

| Component | ESP32 pin | Notes |
|---|---|---|
| MPU6050 SDA | GPIO21 | I²C; 3V3 + GND to the breakout. AD0→GND ⇒ addr `0x68`. |
| MPU6050 SCL | GPIO22 | 4.7 kΩ pull-ups to 3V3 if the breakout lacks them. |
| MPU6050 INT | GPIO4 | optional (data-ready); firmware polls at 50 Hz regardless. |
| Piezo (+) | GPIO34 | through ~1 MΩ to GND (bleed) **and** a Schottky clamp to 3V3 and GND. Input-only ADC1 pin. |
| Piezo (−) | GND | |
| FSR | GPIO35 | FSR from 3V3 to the pin; fixed resistor (~10 kΩ) from the pin to GND (divider). Input-only ADC1 pin. |
| Panic button | GPIO25 → GND | `INPUT_PULLUP`, pressed = LOW. Momentary. Mount where a rider can hit it without looking. |
| Cancel/confirm button | GPIO26 → GND | `INPUT_PULLUP`, pressed = LOW. This is the "I'm OK" button for the 10 s window. |
| Buzzer | GPIO27 | active buzzer (+ to pin, − to GND) or passive via a transistor. |
| Status LED | GPIO2 | onboard LED on most DevKits; solid = BLE linked, blinking = link lost. |
| Battery sense | GPIO32 | optional; divider from VBAT. Set `kVbatWired = true` in `main.cpp` once wired. |
| MQ-3 analog out (AO) | GPIO36 | input-only ADC1 pin (SVP); module's onboard load resistor, no external divider needed. See §"Alcohol pre-ride check" below. |
| MQ-3 heater enable | GPIO23 | GPIO → 1 kΩ → base of a small NPN/MOSFET switching the module's V+ (~150 mA heater). **Do not** wire the heater straight to a GPIO. |

**Power**: bench USB for bring-up. A single-cell LiPo + charger/boost is a
Phase 2 packaging task, not a wiring-diagram item.

**Do not** connect anything here to the motorcycle's electrical system or
ignition. The helmet is electrically isolated from the vehicle by design
(`03_RULES.md` §1, `01_REQUIREMENTS.md` §5).

## Full pin netlist

The table above names each sensor; this is every wire on the board,
including the resistors, diodes, and the transistor between the ESP32 pin
and the part. Part labels (R1, D1, Q1, ...) match the discrete-parts table
right after it.

| ESP32 pin | Connected to (full path) |
|---|---|
| `3V3` | MPU6050 `VCC` · Buzzer `VCC` · FSR leg 1 (→ FSR → node → `GPIO35`) · Piezo clamp: cathode of Schottky **D1** (clamps the `GPIO34` node high) |
| `5V` / `VIN` | MQ-3 module `VCC` only — kept off the 3V3 rail deliberately, see "Alcohol pre-ride check" below |
| `GND` | MPU6050 `GND` + `AD0` (address-select tied low) · panic button leg 2 · cancel button leg 2 · buzzer `GND` · piezo `(−)` lead · far end of **R1** (1 MΩ bleed) · anode of Schottky **D2** · far end of **R2** (10 kΩ, FSR divider) · heater-switch **Q1** emitter |
| `GPIO2` | Onboard LED — nothing external wired |
| `GPIO4` | MPU6050 `INT` (optional, firmware polls at 50 Hz regardless) |
| `GPIO21` | MPU6050 `SDA` |
| `GPIO22` | MPU6050 `SCL` |
| `GPIO23` | **R3** (1 kΩ) → **Q1** base — heater-switch drive line |
| `GPIO25` | Panic button leg 1 (leg 2 → GND) |
| `GPIO26` | Cancel button leg 1 (leg 2 → GND) |
| `GPIO27` | Buzzer `I/O` |
| `GPIO32` | Battery divider node (optional) — see discrete-parts table |
| `GPIO34` | Node shared by: piezo `(+)` lead · **R1** (1 MΩ, other end → GND) · **D1** anode · **D2** cathode |
| `GPIO35` | Node shared by: FSR leg 2 · **R2** (10 kΩ, other end → GND) |
| `GPIO36` | MQ-3 module `AO` (module's onboard load resistor, nothing external needed) |

## Discrete parts (resistors, diodes, transistor)

| Part | Value / model | Between | Purpose |
|---|---|---|---|
| R1 | 1 MΩ | `GPIO34` node ↔ GND | Piezo bleed — drains charge so the ADC reads a spike, not a stuck level |
| D1 | BAT85 / 1N5819 (Schottky) | `GPIO34` node → 3V3 | Clamps positive piezo swings above ~3.5 V |
| D2 | BAT85 / 1N5819 (Schottky) | GND → `GPIO34` node | Clamps negative piezo swings below ~−0.3 V |
| R2 | 10 kΩ | `GPIO35` node ↔ GND | FSR voltage-divider partner |
| R3 | 1 kΩ | `GPIO23` → Q1 base | Base current limiter for the heater switch |
| Q1 | 2N2222 / BC547 (NPN) | collector → MQ-3 `GND` pin · emitter → true GND · base ← R3 | Low-side switch for the ~150 mA MQ-3 heater — `GPIO23` can't source that directly |
| — | 4.7 kΩ ×2 (optional) | SDA/SCL ↔ 3V3 | Only if the MPU6050 breakout lacks onboard I²C pull-ups |
| — | 330 Ω (optional) | `GPIO2` → external LED → GND | Only if swapping the onboard status LED for an external one |
| — | 100 kΩ ×2 (optional) | VBAT → node → GND, node → `GPIO32` | Battery-sense divider (ratio 2.0) — see §3 in `BOM.md`, only needed once battery power is wired |

Mandatory for this build: **R1, R2, R3, D1, D2, Q1** — 3 resistors, 2 diodes,
1 transistor. The pull-up, LED, and battery-divider rows are conditional on
hardware you may not have wired yet.

## ADC notes (ESP32)

- Use **ADC1** pins (GPIO32–39) for piezo/FSR/battery — ADC2 is unavailable
  while Wi-Fi/BLE is active.
- GPIO34/35/36/39 are **input-only** (no internal pull-ups) — fine for the
  analog dividers here.
- The ESP32 ADC is non-linear near the rails; the thresholds in the sensor
  drivers are deliberately loose and get calibrated during bring-up.

## Alcohol pre-ride check (Phase 3, ADR-5)

MQ-3 module VCC through a switch transistor (base via a resistor from
GPIO23, collector/emitter switching the module's power) so the heater
draws nothing between checks — an ESP32 GPIO can't source the ~150 mA an
MQ-3 heater needs. Module's analog output goes straight to GPIO36.

**Per-unit calibration (do this once per physical unit, before its first
pre-ride check):**

1. Flash the firmware, open the serial monitor at 115200 baud.
2. Put the sensor in clean air — away from fuel, hand sanitizer, or
   perfume, all of which the MQ-3 also reacts to.
3. Send the line `CAL`. The firmware warms the heater, averages ~4 s of
   readings once warm, and prints `[CAL] done: valid=1 baseline_adc=...`.
4. The baseline is saved to NVS and survives power cycles. A unit that has
   never run this reports every pre-ride check as `kUncalibrated` — never a
   silent pass (`03_RULES.md` §2).

Re-run `CAL` if the sensor is swapped or a check result looks wrong. The
warm-up duration and the pass/fail ratio (`cfg::mq3` in
`include/build_config.h`) are **PROVISIONAL** placeholders — re-tune them
against real clean-air vs. alcohol-dosed breath samples once hardware
exists (same status as `crash_fusion.cpp`'s thresholds).

The **breath-sampling chamber** (mouthpiece, hygiene handling) is a
separate, still-open physical-design question — none of the above depends
on it being solved; the bare module works for bench bring-up of the
electronics.

## Bring-up order (04_PHASES.md Phase 2)

1. **Panic button + buzzer + cancel button.** Flash, open the serial monitor,
   press panic → you should see `[BTN] panic`, the buzzer pulses for 10 s,
   press cancel → `[BTN] cancel` and a `cancelled` line. This exercises the
   whole SOS state machine with zero other hardware.
2. **MPU6050.** Confirm `MPU6050: ok` at boot. Tip the board over hard while
   tapping the piezo → `crash_impact` SOS.
3. **Piezo.** Tap test; watch `last_impact_peak`.
4. **FSR.** Squeeze → status `helmet_worn` flips to `true`.
5. **BLE.** Pair from `tools/ble_probe.py` or a generic BLE app; watch the
   STATUS notifications and trigger an event.
6. **MQ-3.** Serial `CAL` in clean air for the per-unit baseline (see
   §"Alcohol pre-ride check"), then from `ble_probe.py` press `s`
   (`start_check`) → after the ~20 s warm-up you should see
   `pre_ride_passed` in STATUS flip, or an `alcohol_flag` EVENT if the
   sample is over the baseline ratio.
