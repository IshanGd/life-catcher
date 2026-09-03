# Phase 2 prototype — parts list & assembly

Bench prototype on a breadboard. This is **not** the production BOM — it's
what you buy to bring up the firmware and validate the sensor + fusion +
SOS + BLE path. The MQ-3 alcohol sensor is **Phase 3** and is not here.

Prices are rough India street prices (Sept 2026), for planning only. Common
sources: robu.in, robocraze.com, quartzcomponents.com, Amazon.in, or a local
electronics market (Lamington Road / SP Road / Lajpat Rai).

Pin assignments are the defaults in [`../include/pins.h`](../include/pins.h) —
if you wire differently, edit that file.

---

## 1. Core components (needed for a full bring-up)

| # | Part | Spec / model | Qty | ~₹ | Notes |
|---|------|--------------|-----|----|-------|
| 1 | **ESP32 dev board** | ESP32-WROOM-32, 30-pin "DevKit v1" (CP2102 or CH340 USB) | 1 | 350–550 | Any ESP32-WROOM board works. 38-pin is fine too — pin numbers are the same GPIOs. |
| 2 | **MPU6050 module** | GY-521 breakout (MPU-6050, I²C) | 1 | 80–160 | Has onboard 3V3 regulator + level shifting; runs off 5V or 3V3. |
| 3 | **Piezo disc** | 27 mm piezo element with leads (buy a pack of 5) | 1 pack | 30–70 | The bare disc, *not* a buzzer module. Used as an impact sensor. |
| 4 | **Force-sensing resistor (FSR)** | Interlink FSR 402 (round, ~12.7 mm) **or** RP-C18.3 thin-film clone | 1 | see below | **The cost-sensitive item — see §5.** |
| 5 | **Tactile push buttons** | 6×6 mm through-hole, momentary (pack of 10) | 1 pack | 25–50 | Need 2 (panic, cancel). |
| 6 | **Buzzer** | 5 V **active** buzzer module (3-pin, has driver transistor) | 1 | 20–45 | Active module = drive straight from a GPIO. A bare passive element needs a transistor — see §4.6. |
| 7 | **Breadboard** | 830-point (MB-102) | 1 | 70–130 | |
| 8 | **Jumper wires** | M–M and M–F, 20 cm (40+40 pack) | 1 pack | 90–160 | |
| 9 | **Resistor assortment** | 1/4 W, needs values: 1 MΩ ×1, 10 kΩ ×2, 100 kΩ ×2, 330 Ω ×1, 1 kΩ ×1 | 1 pack | 80–150 | A 600-piece E12 pack covers everything here and later. |
| 10 | **Schottky diodes** | BAT85 / 1N5819 (pack of 10) | 1 pack | 25–50 | Piezo input clamp (§4.3). 1N4148 works in a pinch but leaks more. |
| 11 | **USB data cable** | micro-USB or USB-C to match your board | 1 | 0–100 | Often bundled with the board. Must be a **data** cable, not charge-only. |

**Core subtotal (with RP-C18.3 clone FSR): ~₹800–1,250**
**Core subtotal (with genuine FSR 402): ~₹1,150–1,800**

Both land in / near the `01_REQUIREMENTS.md` §5 target of **₹860–1,370 for
sensors + MCU** — the FSR is the swing factor (§5).

---

## 2. Minimum to start *today* (panic-button bring-up, step 1)

You don't need the sensors to exercise the whole SOS state machine:

| Part | ~₹ |
|---|---|
| ESP32 dev board | 350–550 |
| 2 × tactile buttons | ~10 |
| 1 × active buzzer module | 20–45 |
| Breadboard + jumpers | 160–290 |
| **Total** | **~₹550–900** |

Flash, open the serial monitor, press the panic button → buzzer pulses for
10 s → press cancel → `[BTN] cancel` + a `cancelled` event line. That
validates `sos_state_machine` + `buzzer` + both buttons on real silicon.

---

## 3. Optional — battery / portable power (not required for bench work)

| Part | Spec | ~₹ | Notes |
|---|---|----|-------|
| LiPo cell | 1S 3.7 V, 500–1000 mAh, JST-PH | 200–380 | Or skip and run the board off a USB power bank. |
| Charger module | TP4056 with protection (USB-C) | 15–35 | |
| Boost converter | MT3608 (set output to 5 V) | 30–55 | ESP32 peaks ~500 mA on TX; feed the board's 5V/VIN pin. |
| Battery sense | 2 × 100 kΩ (from the assortment) | – | Divider on GPIO32, ratio 2.0 = `VBAT_DIVIDER_RATIO` in `pins.h`. Set `kVbatWired = true` in `src/main.cpp` once wired. |

Leave `battery_pct` reporting `-1` (unknown) until this is in — the firmware
already handles that.

---

## 4. Assembly

Breadboard layout. **One common ground** for everything. Board powered by
USB during bring-up.

> **Never connect any of this to the motorcycle's wiring or ignition.**
> The helmet unit is electrically isolated from the vehicle by design
> (`03_RULES.md` §1, `01_REQUIREMENTS.md` §5). There is no ignition wire in
> this circuit and there must never be one.

### 4.0 Power rails

- ESP32 `3V3` → breadboard **+ rail** (call it 3V3).
- ESP32 `GND` → breadboard **− rail** (GND). Use a second GND pin for the
  other rail and bridge them.

### 4.1 MPU6050 (I²C) — accel + gyro

```
MPU6050        ESP32
  VCC  ───────  3V3        (module regulates internally; 5V also ok)
  GND  ───────  GND
  SCL  ───────  GPIO22
  SDA  ───────  GPIO21
  AD0  ───────  GND        (sets I2C address 0x68 — matches MPU6050_I2C_ADDR)
  INT  ───────  GPIO4      (optional; firmware polls at 50 Hz anyway)
  XCL, XDA      (leave unconnected)
```

If the module has no pull-ups and I²C is flaky, add 4.7 kΩ from SDA→3V3 and
SCL→3V3. Most GY-521 boards already have them.

### 4.2 FSR — wear detection (voltage divider, GPIO35)

```
3V3 ──[ FSR ]──┬──[ 10kΩ ]── GND
               │
              GPIO35   (ADC1_CH7, input-only — no pull-up needed)
```

- No pressure → FSR ≈ MΩ → GPIO35 near 0 V.
- Helmet worn (pressure) → FSR drops to kΩ → GPIO35 rises.
- 10 kΩ is a starting value; tune with the `on`/`off` counts in
  `src/sensors/fsr_wear.h` during bring-up. If you don't have an FSR yet,
  temporarily wire a spare push button from 3V3 to GPIO35 (with a 10 kΩ from
  GPIO35 to GND) to fake "worn".

### 4.3 Piezo — impact sensor (clamped analog, GPIO34)

A struck piezo can swing tens of volts — it **must** be clamped before it
touches the ESP32.

```
                   ┌───────────────┬──────── GPIO34  (ADC1_CH6, input-only)
                   │               │
piezo (+) ─────────┤          [ Schottky ]  cathode → 3V3   (clamp high)
                   │               │
                  [ 1 MΩ ]    [ Schottky ]  anode ← GND, cathode → node
                   │               │                         (clamp low)
piezo (−) ─── GND ─┴───────────────┘
```

- **1 MΩ** from the GPIO34 node to GND — bleeds the charge so you read a
  spike, not a latched level.
- **Schottky #1**: anode to the node, cathode to **3V3** — dumps anything
  above ~3.5 V.
- **Schottky #2**: anode to **GND**, cathode to the node — clamps negative
  swings to ~−0.3 V.
- Tune the trigger with `threshold_counts` in `src/sensors/piezo.h`.

Mount the piezo flat against a rigid surface (later: the helmet shell). On
the bench, tape it to the table and tap near it.

### 4.4 Panic button (GPIO25)

```
GPIO25 ──[ button ]── GND
```

Firmware uses `INPUT_PULLUP`, so pressed = LOW. No external resistor.
Add a 100 nF cap across the button if you see double-triggers (the driver
also debounces in software).

### 4.5 Cancel / confirm button (GPIO26)

```
GPIO26 ──[ button ]── GND
```

Same as the panic button. This is the "I'm OK" button for the 10 s window.

### 4.6 Buzzer (GPIO27)

**Active buzzer module (recommended):** 3 pins.
```
module VCC ── 3V3 (or 5V per the module)
module GND ── GND
module I/O ── GPIO27
```

**Bare passive piezo element:** an ESP32 GPIO can only source ~12 mA safely.
A loud element needs a small transistor:
```
GPIO27 ──[ 1kΩ ]── base (2N2222 / BC547)
3V3 ──[ buzzer ]── collector ;  emitter ── GND
flyback diode (1N4148) across the buzzer, cathode to 3V3
```
The firmware just toggles GPIO27 HIGH/LOW in patterns — either wiring works.

### 4.7 Status LED (GPIO2)

Most DevKit boards have an onboard LED on GPIO2 — **nothing to wire**. It
shows BLE link state (solid = linked, blinking = link lost). For an external
one: `GPIO2 ──[ 330Ω ]──[ LED ]── GND`.

### 4.8 Battery sense (optional, GPIO32)

Only if you added §3 power. Divider from the raw battery node:
```
VBAT ──[ 100kΩ ]──┬──[ 100kΩ ]── GND
                  │
                GPIO32   (ADC1_CH4)
```
Ratio = 2.0 → matches `VBAT_DIVIDER_RATIO`. Set `kVbatWired = true` in
`src/main.cpp`.

### Pin summary (from `include/pins.h`)

| GPIO | Net | Type |
|---|---|---|
| 21 | I²C SDA (MPU6050) | digital |
| 22 | I²C SCL (MPU6050) | digital |
| 4  | MPU6050 INT (optional) | digital in |
| 34 | Piezo (clamped) | ADC1 in-only |
| 35 | FSR divider | ADC1 in-only |
| 25 | Panic button → GND | digital in (pullup) |
| 26 | Cancel button → GND | digital in (pullup) |
| 27 | Buzzer | digital out |
| 2  | Status LED (onboard) | digital out |
| 32 | Battery divider (optional) | ADC1 in |

**ADC rule:** piezo/FSR/battery are all on **ADC1** (GPIO32–39) — ADC2 is
unusable while BLE/Wi-Fi is active. GPIO34/35 are input-only (no internal
pull-ups), which is exactly what the dividers need.

---

## 5. Cost-target note (`03_RULES.md` §1)

`01_REQUIREMENTS.md` §5 targets **₹860–1,370** for sensors + MCU. The FSR is
the line item that can break it:

- **Genuine Interlink FSR 402:** ~₹400–700 → total pushes to ₹1,150–1,800,
  **over** the sensor+MCU target on its own.
- **RP-C18.3 / DF9-40 thin-film clone:** ~₹150–300 → total ~₹800–1,250,
  **within** target. Adequate for prototype wear-detection (it only needs to
  say worn / not-worn, not measure force).
- **Production path:** a bulk thin-film sensor or a simple sprung contact
  switch under the padding is likely the real answer. Flagging now rather
  than quietly speccing the ₹700 part.

Everything else here is comfortably cheap; the ESP32 + MPU6050 + piezo +
buttons + buzzer is ~₹500–800 combined.

---

## 6. After it's assembled

Follow the bring-up order in [`WIRING.md`](WIRING.md) §"Bring-up order":
panic button first, then MPU6050 + piezo fusion, then FSR, then BLE via
`tools/ble_probe.py`. Before wiring anything, you can already run the logic
against real data with `pio run -e sim` (see the firmware README).
