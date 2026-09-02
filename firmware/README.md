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
│   │   └── link_monitor.h    BLE-link-down → fail-visibly
│   ├── sensors/          # one driver per sensor (03_RULES.md §4)
│   │   ├── imu_mpu6050.*  piezo.h  fsr_wear.h
│   │   ├── panic_button.h  cancel_button.h  button.h  buzzer.h
│   ├── ble/gatt_server.* # NimBLE GATT server
│   └── main.cpp          # plumbing only — no rule logic here
├── test/                 # host (native) unit tests — no board needed
└── tools/ble_probe.py    # desktop BLE client for bring-up
```

## Build / flash / test

```bash
pip install platformio

pio run                    # build for esp32dev
pio run -t upload          # flash (board on USB)
pio device monitor         # serial console @ 115200

pio test -e native         # run all host unit tests
pio test -e native -f test_sos_state_machine   # just the safety-critical one
```

> Nothing in `firmware/` has been compiled in this repo's authoring
> environment (no C++ toolchain here). `pio run` / `pio test` on your machine
> is the first real compile — expect to fix a NimBLE API nit or two against
> the exact library version PlatformIO resolves.

## What's real vs. provisional

| Piece | State |
|---|---|
| SOS state machine (10 s window, fusion-gate, cancel logging) | **complete**, host-tested — this is the safety core |
| BLE JSON schema + serialization | complete, host-tested |
| MPU6050 / piezo / FSR / button / buzzer drivers | complete, **not tested on hardware** |
| NimBLE GATT server | complete, **not compiled**; callback signatures target NimBLE 1.4.x |
| **`crash_fusion.cpp` thresholds** | **PROVISIONAL hand-set values.** Not the ML model. Must be re-tuned against drop-test data and then replaced by the ported Random Forest once `ml/README.md` shows a trustworthy crash model (ADR-3). |
| Battery %, `pre_ride_passed` | stubbed (`-1` / `false`) — battery curve is a BOM task, pre-ride gate is Phase 3 |

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
  there must never be one.

## Open decision for a human — panic button behaviour

Right now the panic button runs the **same** 10 s buzzer + cancel window as a
crash (rule-compliant default). For a robbery/assault, a loud buzzer and a
delay may be exactly wrong. Options to decide (do **not** change unilaterally
— `03_RULES.md` §1 covers the cancel window):

1. keep as-is (safe default, matches the locked crash behaviour);
2. panic → **silent** countdown (no buzzer), same 10 s, cancel via a
   double-press;
3. panic → immediate silent dispatch, no window.

`cfg::kPanicUsesCancelWindow` is the single hook; option 3 would need sign-off
because it removes a confirm window.
