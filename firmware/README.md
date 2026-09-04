# Smart Helmet firmware (ESP32)

Phase 2 prototype firmware: read the sensors, fuse a crash decision, run the
10-second cancel window, relay status + events to the companion app over BLE.

## Layout

```
firmware/
├── platformio.ini
├── include/
│   ├── pins.h            # board pin map — edit for your wiring
│   └── build_config.h    # timing / thresholds (NOT per-unit calibration)
├── src/
│   ├── core/             # framework-agnostic, host-tested, rule-bound logic
│   │   ├── ble_schema.*      02_ARCHITECTURE.md §4 JSON contract (versioned)
│   │   ├── imu_window.h      50 Hz / 100-sample ring + features (== ml/features.py)
│   │   ├── crash_fusion.*    PROVISIONAL threshold classifier (see below)
│   │   ├── sos_state_machine.*   the 10 s cancel window + event lifecycle
│   │   ├── link_monitor.h    BLE-link-down → fail-visibly
│   │   ├── alcohol_calibration.h Phase 3: per-unit MQ-3 baseline + store interface
│   │   ├── mq3_sampling.h    Phase 3: shared warm-up + averaging primitive
│   │   ├── mq3_calibration.h Phase 3: assembly-line calibration routine
│   │   └── preride_check.*   Phase 3: the check-in state machine (ADR-5)
│   ├── sensors/          # one driver per sensor (03_RULES.md §4)
│   │   ├── imu_mpu6050.*  piezo.h  fsr_wear.h  mq3_alcohol.h
│   │   ├── mq3_calibration_store.h   NVS-backed ICalibrationStore
│   │   ├── panic_button.h  cancel_button.h  button.h  buzzer.h
│   ├── ble/gatt_server.* # NimBLE GATT server
│   ├── sim/main.cpp      # desktop simulator: real core/ vs an IMU-window CSV
│   └── main.cpp          # plumbing only — no rule logic here
├── test/                 # host (native) unit tests — no board needed
├── tools/ble_probe.py    # desktop BLE client for bring-up
├── wokwi.toml            # ESP32 simulation (Wokwi)
└── diagram.json
```

## Build / flash / test

```bash
pip install platformio

pio run                    # build for esp32dev
pio run -t upload          # flash (board on USB)
pio device monitor         # serial console @ 115200

pio test -e native         # run all host unit tests  -> 32/32 passing
pio test -e native -f test_sos_state_machine   # just the safety-critical one
pio run  -e sim            # build the desktop simulator (see below)
```

The `native` and `sim` environments need a host C/C++ compiler on `PATH`. On
Windows: `winget install BrechtSanders.WinLibs.POSIX.UCRT` (GCC), then open a
**new** terminal so the PATH update takes effect. `pio test -e native` and
`pio run -e sim` were last run green on GCC 16.1.0 (2026-09).

`pio run -e esp32dev` downloads its own toolchain (xtensa-esp32) the first
time — no relation to the GCC above. **On Windows with the Microsoft Store
Python** (`python.exe` under `...\WindowsApps\...`), that first run can fail
with `ERROR: Can not combine '--user' and '--target'`: the Store build
ships a site-level `pip.ini` that forces `--user`, which conflicts with
PlatformIO's `pip install --target` for esptoolpy's dependencies. Fix:
`set PIP_USER=no` (or `$env:PIP_USER = "no"` in PowerShell) before running
`pio`. Confirmed working: `pio run -e esp32dev` → SUCCESS, RAM 12.0%
(39420/327680 B), Flash 49.3% (646269/1310720 B) (2026-09).

## Do you need to buy hardware? Not yet.

Three levels, cheapest first. You can get a long way before any parts arrive.

### 1. Desktop simulator — runs the REAL `src/core/` logic, no board

```bash
pio run -e sim
.pio/build/sim/program --csv ../ml/data/damoto_windows.csv --verbose
.pio/build/sim/program --csv ../ml/data/synthetic/windows.csv --cancel-after 4
```

Replays IMU windows (from the ML pipeline CSVs — including the **real DAMOTO
fall data**) through `ImuWindow → crash_fusion → SosStateMachine` and prints
the exact BLE JSON the firmware would send. The piezo channel isn't in those
CSVs so it's synthesised (`--piezo-threshold`, default 1.8 g). This is the
best way to watch crash detection + the 10 s cancel window behave against
real data. Source: `sim/main.cpp`.

### 2. Wokwi — simulates the ESP32, pins, I²C sensors and serial

Free browser / VS Code ESP32 simulator. Good for the Arduino layer: real
`MPU6050` model, buttons, buzzer, serial monitor, `pio` build.
`wokwi.toml` + `diagram.json` are in this folder — build with
`pio run -e esp32dev`, then open `firmware/` with the Wokwi VS Code
extension (Ctrl/Cmd-Shift-P → "Wokwi: Start Simulator"), or paste both files
into a new project on wokwi.com. The two potentiometers stand in for the
piezo (turn up = impact) and the FSR (turn up = helmet worn).
Limitations: Wokwi's BLE is partial — you can see it advertise, but pairing a
real phone is unreliable. Use the desktop sim (1) for the BLE contract and
Wokwi for the sensor/pin wiring feel.

### 3. Real hardware — ~₹800–1,800 of parts

Full parts list (with India sourcing + prices), a "minimum to start today"
subset, and a step-by-step breadboard walkthrough are in
[`docs/BOM.md`](docs/BOM.md); the pin reference is
[`docs/WIRING.md`](docs/WIRING.md). This is the actual Phase 2 exit —
simulation can't validate mounting, vibration, battery life, or BLE range.

## Compile status

- `src/core/` (including the Phase 3 alcohol pre-ride check) + the desktop
  sim + all `native` tests: **compiled and green** on GCC 16.1.0 (2026-09).
  `pio test -e native` → 32/32.
- `src/sensors/`, `src/ble/`, `src/main.cpp` (the full ESP32 build):
  **compiled and green** — `pio run -e esp32dev` → SUCCESS (2026-09,
  espressif32@6.13.0, NimBLE-Arduino@1.4.3, Adafruit MPU6050@2.2.9). RAM
  12.0% (39420/327680 B), Flash 49.3% (646269/1310720 B). No NimBLE API
  drift hit — resolved cleanly against 1.4.x (see the callback-signature
  table below in case you ever bump the library). `firmware.bin` exists but
  has not been flashed to a physical board yet (no hardware).

The `NimBLE-Arduino` library **changed three callback function signatures**
between v1.x and v2.x:

| callback | v1.4.x (what this code uses) | v2.x |
|---|---|---|
| `NimBLEServerCallbacks::onConnect` | `onConnect(NimBLEServer*)` | `onConnect(NimBLEServer*, NimBLEConnInfo&)` |
| `NimBLEServerCallbacks::onDisconnect` | `onDisconnect(NimBLEServer*)` | `onDisconnect(NimBLEServer*, NimBLEConnInfo&, int reason)` |
| `NimBLECharacteristicCallbacks::onWrite` | `onWrite(NimBLECharacteristic*)` | `onWrite(NimBLECharacteristic*, NimBLEConnInfo&)` |

`platformio.ini` pins `h2zero/NimBLE-Arduino@~1.4.3` with
`espressif32@^6.7.0` — confirmed compiling clean against that pin. If you
ever bump the library and get an `error: 'onConnect' marked 'override' but
does not override`, add the `NimBLEConnInfo&` params to those three
overrides in `gatt_server.cpp` (the bodies don't change).

## What's real vs. provisional

| Piece | State |
|---|---|
| SOS state machine (10 s window, fusion-gate, cancel logging) | **complete**, host-tested (10 tests green) — this is the safety core |
| BLE JSON schema + serialization | complete, host-tested (6 tests green) |
| crash fusion classifier | complete, host-tested (6 tests green) — thresholds provisional (see below) |
| desktop simulator | complete, runs on synthetic + real DAMOTO windows |
| MPU6050 / piezo / FSR / button / buzzer / MQ-3 drivers | complete, **compiles clean for esp32dev**, not tested on hardware |
| NimBLE GATT server | complete, **compiles clean for esp32dev** against NimBLE 1.4.3, not tested on hardware |
| **`crash_fusion.cpp` thresholds** | **PROVISIONAL hand-set values.** Not the ML model. Must be re-tuned against drop-test data and then replaced by the ported Random Forest once `ml/README.md` shows a trustworthy crash model (ADR-3). |
| Battery %, `pre_ride_passed` | battery still stubbed (`-1`, needs the divider wired — see BOM §3); `pre_ride_passed` is now real (reflects `PreRideCheckStateMachine`), pending an actual MQ-3 |
| Pre-ride check-in / MQ-3 driver / calibration store | complete, host-tested (9 tests green) — thresholds provisional (see below), **not run against a physical MQ-3** |
| **`cfg::mq3` warm-up / ratio-threshold** | **PROVISIONAL hand-set values,** same caveat as crash fusion. Needs re-tuning against real clean-air vs. alcohol-dosed breath samples once hardware exists. |

## Rule-bound behaviour (03_RULES.md)

- **No single-sensor crash SOS.** `SosStateMachine::Trigger()` rejects a
  `crash_impact` whose `confirmed_by` names < 2 sources; `Classify()` never
  returns an emergency without the piezo. (ADR-4)
- **The 10 s cancel window is fixed.** `cfg::kSosCancelWindowMs`, no setter,
  no skip path. Every SOS (crash *and* panic) runs it.
- **Cancellations are logged**, emitted as their own `cancelled` event —
  never silently dropped — so fleets/insurers get real false-positive rates.
- **Fail visibly.** `LinkMonitor` drives the LED + buzzer when the phone
  link drops while the helmet is worn.
- **No ignition control.** There is no such output pin or code path, and
  there must never be one — including from the alcohol pre-ride check.
- **Alcohol sensor framing.** Never described as a "breathalyzer" or "BAC"
  reading anywhere in code, logs, or (eventually) app strings — it's an
  ethanol-vapor screen for an internal gate.
- **Per-unit calibration, never a firmware constant.** The MQ-3 baseline
  lives in `core::AlcoholCalibration`, persisted via NVS
  (`sensors::Mq3CalibrationStore`) — see "Alcohol pre-ride check" below.

## Alcohol pre-ride check — Phase 3 (ADR-5)

Gated, one-shot, app-initiated: the app sends `{"cmd":"start_check"}` after
the driver dons the helmet, before it lets them go online.
`PreRideCheckStateMachine` warms the MQ-3 heater, samples for
`cfg::mq3::kSampleWindowMs`, and compares the average against the unit's
calibrated clean-air baseline. A fail emits one `alcohol_flag` event
(`confirmed_by: ["mq3"]`) — it is **not** an SOS: single-sensor by design
(ADR-5 makes this a gate, not a fusion-confirmed emergency), never routed
through `SosStateMachine`, and there's no path from a fail to vehicle
ignition.

A unit with no calibration on file reports `kUncalibrated`, never a silent
pass — run the calibration step first:

```
1. Open the serial monitor (115200 baud).
2. Put the MQ-3 in clean air, well away from fuel/sanitizer/perfume.
3. Send the line: CAL
4. Wait ~24 s (kWarmupMs + kSampleWindowMs) for "[CAL] done: valid=1 baseline_adc=...".
```

This baseline is saved to NVS and survives power cycles. Re-run `CAL`
any time the sensor is replaced or drifts — see `firmware/docs/WIRING.md`
"Per-unit calibration" for the assembly-line version of this procedure.

## Panic button behaviour — DECIDED

The panic button runs the **same** 10 s buzzer + cancel window as a crash
(`cfg::kPanicUsesCancelWindow = true`). A silent / no-window variant for
assault scenarios was considered and rejected — it would remove a confirm
window (`03_RULES.md` §1). Revisit only with a human decision.
