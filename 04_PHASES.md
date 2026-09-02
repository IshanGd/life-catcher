# Smart Helmet — Phases & Roadmap

Status snapshot below reflects the project's own progress tracking as of
Aug 2026. Statuses: **Concept → Design → Prototype → Validated → Pilot-ready**.
Update this table as work lands — don't let it drift from `03_RULES.md` §5.

## Current status by component

| Lane | Component | Status | Note |
|---|---|---|---|
| Hardware & Sensors | MPU6050 + ML crash detection | Design | Driver written (`firmware/src/sensors/imu_mpu6050.*`, ±16 g / ±2000 dps, 50 Hz → same units as `ml/`) — not yet run on a physical MPU6050 |
| Hardware & Sensors | Piezo impact sensor | Design | Driver + fusion gate written (`firmware/src/sensors/piezo.h`, `core/crash_fusion.*`) — not yet wired |
| Hardware & Sensors | FSR wear detection | Design | Driver written with hysteresis (`firmware/src/sensors/fsr_wear.h`) — placement/thresholds TBD on hardware |
| Hardware & Sensors | ESP32 + BLE architecture | Design | NimBLE GATT server written (`firmware/src/ble/`), versioned schema — not yet compiled/flashed |
| Hardware & Sensors | Panic / SOS button | Design | Driver + SOS trigger path written & host-tested — ready to flash + wire first (Phase 2 bring-up step 1) |
| Hardware & Sensors | MQ-3 alcohol sensor + breath chamber | Design | Phase 3 — deliberately absent from the Phase 2 firmware build |
| Hardware & Sensors | Cancel/confirm buzzer + UX | Design | Buzzer driver + the 10 s cancel-window state machine written & host-tested (`firmware/src/core/sos_state_machine.*`) |
| Firmware & Intelligence | Crash-detection ML pipeline (code) | Prototype | `ml/` runs end-to-end on synthetic **and** real data; group-aware out-of-fold evaluation; reports crash-class FN/FP per `03_RULES.md` §3; 8 smoke tests |
| Firmware & Intelligence | Crash-detection **dataset** (real) | **In progress** | DAMOTO loaded & verified (`ml/loaders/damoto.py`); first non-synthetic run done — 0% missed / 0% false-alarm on crash, group-aware, BUT only 4 fall events, all ~90 km/h full-rotation track falls with saturated sensors → **not a field-accuracy result** (`ml/README.md` §Results). Still needed: low-speed tip-over data, real Indian-road pothole data, controlled drop-tests (Phase 2). |
| Firmware & Intelligence | Ride behavior scoring | Concept | Concept agreed (accel + phone GPS) — scoring model/thresholds not yet designed |
| Firmware & Intelligence | Shift fatigue / nudge logic | Concept | Concept agreed — nudge timing/thresholds not yet designed |
| Software & App | Driver-facing app UI | Prototype | iOS + Android mockup built with sample data — no backend/real functionality yet |
| Software & App | Fleet-Ops Dashboard | Design | Full 3-view spec now exists (fleet ops / insurer claims / support, `05_DESIGN.md` §3) with an access model (`02_ARCHITECTURE.md` §7) — no UI or backend built yet |
| Software & App | BLE data pipeline (helmet ↔ app) | Prototype (firmware side) | Firmware side written: `firmware/src/core/ble_schema.*` (versioned JSON, host-tested) + NimBLE GATT server + `tools/ble_probe.py` desktop client. App side still not started. |
| Firmware & Intelligence | Helmet firmware (Phase 2) | Prototype | `firmware/` scaffolded: safety-critical SOS state machine (fusion-only crash, fixed 10 s cancel window, logged cancellations) + fusion classifier + sensor drivers + BLE, with host unit tests. **Not compiled or run on hardware yet.** Crash fusion uses PROVISIONAL thresholds, not the ported ML model. |
| Firmware & Intelligence | Continuous data flywheel (confirm/cancel → retraining) | Design | Architecture defined (ADR-6) — depends on Phase 2 hardware and a consent flow (`06_GOVERNANCE.md`) before going live |
| Business & Market | Market & competitive landscape | Validated | Zomato, Rapido, Ola, AVRO Helmets mapped; differentiation identified |
| Business & Market | B2B2C GTM strategy | Design | Path defined (fleet-leasing/insurer pilot before platform HQ) — no partner conversations started |
| Business & Market | Pilot partner (fleet/insurer) | **Not started** | Not yet identified or approached |
| Business & Market | Regulatory strategy (ETA/telecom) | Design | BLE-only architecture avoids ETA certification requirement by design |
| Business & Market | Data-use / consent governance policy | **Not started** | Coaching-vs-disciplinary use of safety scores, driver consent for the retraining flywheel, and third-party data sharing all undocumented — see `06_GOVERNANCE.md` |
| Business & Market | Revenue model | **Not started** | Hypothesis stated (device + subscription, `01_REQUIREMENTS.md` §4.5) but unvalidated |

**Note on the ML pipeline:** `ml/` now runs end-to-end on both synthetic and
real (DAMOTO) data, with group-aware out-of-fold evaluation and documented
crash-class FN/FP rates (`ml/README.md` §Results). The formal Phase 1 exit
criterion — "a model trained and evaluated on non-synthetic data, with
documented false-positive/false-negative rates" — is **met**. But per
`01_REQUIREMENTS.md` §4.3 **[LOCKED]** the 0%/0% crash result is *not* a
field-accuracy claim: DAMOTO has only 4 fall events, all high-speed
full-rotation track falls with saturated sensors, and the model keys on the
easy multi-second on-its-side aftermath. A trustworthy crash model still
needs low-speed tip-over data, real pothole data, and controlled drop-tests
(Phase 2). Risk #1 below stays open.

## Critical path (what actually gates progress, in order)

1. **ML crash-detection dataset.** Real data now flows through the pipeline
   (DAMOTO), but the crash class rests on 4 high-speed track falls only. A
   *trustworthy* crash model — the thing pilot pitch and insurer trust
   depend on — still needs low-speed tip-over data, real Indian-road pothole
   data, and controlled drop-tests (blocked on Phase 2 hardware).
2. **Physical prototype build.** Every hardware row is still at "design,"
   not "prototype" — nothing has been soldered or assembled yet.
3. **Alcohol sensor breath-chamber design.** The one hardware piece with an
   unresolved physical-design question (mouthpiece/hygiene), not just a
   wiring task.
4. **Pilot partner outreach.** The GTM path is defined but has zero real-
   world traction; this can start in parallel with hardware work, not after.
5. **Data-use governance policy.** Must be drafted and agreed with the first
   pilot partner *before* that pilot's contract is signed — not during or
   after. This gates both the confirm/cancel retraining flywheel (ADR-6)
   and any Fleet-Ops Dashboard feature that exposes a driver's score to a
   fleet/insurer. See `06_GOVERNANCE.md`.

## Phase plan

### Phase 0 — Foundations (done)
- Market/competitive research, feature categorization, B2B2C GTM strategy.
- Companion app UI mockup (iOS + Android) with sample data.
- ML pipeline scaffolding validated on synthetic data.
- Architecture decisions locked (phone-offload, ESP32+BLE, fusion-only
  triggers, gated alcohol check) — see `02_ARCHITECTURE.md`.

**Exit criteria (met):** requirements, architecture, and design docs exist
and are internally consistent; a runnable ML scaffold and a clickable app
mockup both exist.

### Phase 1 — Real crash-detection data (critical path #1)

**Done:**
- DAMOTO located (supplementary ZIPs on PMC — Data in Brief 23:103828 +
  corrigendum 30:105577, **not** Mendeley) and loaded via
  `ml/loaders/damoto.py` + `base.py`: tab-sep CSV parse, 1 kHz → 50 Hz
  anti-aliased decimation, m/s²→g, fall-window labelling from Table 1
  timestamps, harsh-braking event detection, a `LABEL_PLAN` mapping DAMOTO
  scenarios to the 4-class schema, and a `group` column (source event) for
  leak-free evaluation.
- First non-synthetic training run (`models/rf_crash_damoto.pkl`): RF,
  222 windows, **group-aware out-of-fold** 3-fold CV — 0/60 missed crashes,
  0/162 false alarms, 0/41 fall-like near-falls misflagged. Full write-up
  and the honest caveats in `ml/README.md` §Results.
- `pothole_bump` sourced from DAMOTO "Much degraded track" (rough-road) as a
  stand-in.

**Still open (needed for a *trustworthy* crash model, not the exit criterion):**
- Low-speed urban tip-over data — DAMOTO is all ~90 km/h full-rotation falls.
- Real Indian-road pothole data — the current pothole class is one
  rough-road recording from a different logger session.
- Controlled drop-tests (helmet dropped from set heights, simulated hard
  stops, real pothole rides) once hardware exists — highest-value data
  activity once Phase 2 lands.
- SisFall / UMAFall / UP-Fall for negative-class diversity only, never as a
  crash substitute.

**Exit criteria:** a model trained and evaluated on non-synthetic data, with
documented false-positive/false-negative rates. — **met** (`ml/README.md`
§Results); the result is explicitly not a field-accuracy claim (see the
note above and `01_REQUIREMENTS.md` §4.3 [LOCKED]).

### Phase 2 — Physical prototype build

**Firmware — done (in repo, `firmware/`), not yet compiled or on hardware:**
- PlatformIO / Arduino project for `esp32dev`.
- Safety-critical core (`src/core/`, framework-agnostic, host unit tests):
  SOS state machine (fusion-only crash trigger per ADR-4, fixed 10 s cancel
  window per `03_RULES.md` §1, cancellations emitted as logged events per
  §2), the IMU window/feature code (same 50 Hz / 100-sample shape and units
  as `ml/`), a provisional threshold fusion classifier, and the
  BLE-link-down "fail visibly" monitor.
- One driver per sensor (`src/sensors/`): MPU6050, piezo, FSR, panic button,
  cancel button, buzzer.
- NimBLE GATT server (`src/ble/`) emitting the versioned schema
  (`02_ARCHITECTURE.md` §4) + `tools/ble_probe.py` desktop client.
- Wiring/pinout doc + bring-up order in `firmware/docs/WIRING.md`.

Simulation before hardware (no parts needed): `pio run -e sim` builds a
desktop simulator (`firmware/src/sim/`) that runs the real `core/` logic
against the ML window CSVs — including the real DAMOTO falls — and prints the
BLE JSON. Wokwi (`firmware/wokwi.toml` + `diagram.json`) simulates the ESP32
+ sensors + serial. See `firmware/README.md` §"Do you need to buy hardware?".

Panic-button behaviour: **decided** — same 10 s window + buzzer as a crash
(`03_RULES.md` §1 rationale), `cfg::kPanicUsesCancelWindow = true`.

**Still to do (needs physical hardware — the actual Phase 2 work):**
- `pio run` / `pio test -e native` — first real compile; fix any NimBLE API
  drift against the resolved library version.
- Assemble MPU6050 + piezo + FSR + ESP32 + panic button + buzzer per
  `01_REQUIREMENTS.md` §4.1 / `firmware/docs/WIRING.md`. Panic button first.
- Bring-up on the bench: verify each sensor, then the full
  crash-fusion → cancel-window → BLE path against `ble_probe.py`.
- Tune `crash_fusion.cpp` thresholds on real ride/drop data; feed that data
  back to Phase 1.
- Package into a wearable form on a helmet shell (raise the BIS/ISI
  re-certification question from `06_GOVERNANCE.md` §6 here).

**Exit criteria:** a working, wearable prototype relaying live sensor data
over BLE to a test harness or the app.

### Phase 3 — Alcohol sensor integration
- Design and prototype the enclosed breath-sampling chamber (mouthpiece,
  hygiene handling) — the unresolved physical-design piece.
- Implement the pre-ride "check-in" gate flow (post-donning, pre-"go
  online") and per-unit calibration step.

**Exit criteria:** a repeatable, documented per-unit calibration process and
a working pre-ride check-in flow on real hardware.

### Phase 4 — Companion app: real functionality
- Replace the mockup's sample data with the live BLE pipeline from Phase 2,
  through the app's single data-service seam (`02_ARCHITECTURE.md` §5).
- Implement ride behavior scoring and fatigue nudge logic (currently
  concept-only) against real accel + phone GPS data.
- Implement SOS relay via phone data/SMS + phone GPS.

**Exit criteria:** the app mockup screens are backed by real device data and
a real (not simulated) SOS path, tested end-to-end.

### Phase 5 — Fleet-Ops Dashboard
- Build against the now-complete spec in `05_DESIGN.md` §3: the three
  role-scoped views (fleet ops manager, insurer claims processor, customer
  support), backed by the access model in `02_ARCHITECTURE.md` §7.
- **Blocked on the governance policy (critical path #5) landing first** for
  the fleet-ops manager's driver drill-down and any score-visibility
  feature — the UI can be built in parallel, but must not go live with real
  driver data until the coaching-vs-disciplinary policy is signed off.
- Deliberately sequenced after the driver-facing app has real data —
  building fleet aggregation before there's real per-driver data to
  aggregate is wasted work.

**Exit criteria:** a fleet-ops manager can see aggregate metrics and drill
into a real driver's record; an insurer can pull a real incident export;
support can look up real device health — each scoped per
`02_ARCHITECTURE.md` §7, and the governance policy is signed off before any
of this touches real driver data.

### Phase 6 — Pilot
- Approach a first partner: regional fleet-leasing company, city-level
  delivery aggregator, or an insurer underwriting gig-driver policies —
  not a direct approach to a major platform's HQ.
- Run the pilot to generate real-world false-positive/negative, durability,
  and battery-life data.
- Use pilot data as the evidence base for later platform conversations.

**Exit criteria:** documented pilot results (accuracy, durability, battery
life) and at least one follow-on conversation with a larger platform,
positioned explicitly against Zomato (wear-compliance only) and AVRO
Helmets (undifferentiated crash-detection) using the alcohol + behavior-
scoring + fatigue bundle as the wedge.

## Sequencing notes for Claude Code

- Do not start Phase 5 (fleet dashboard) work before Phase 1 (real data) and
  Phase 2 (hardware) are substantially underway — there's nothing real to
  aggregate yet, and it risks locking in a data model before the real event
  schema is proven on hardware.
- Phase 3 (alcohol chamber) and Phase 6 (pilot outreach) can run in parallel
  with Phase 1/2 — they don't block or get blocked by the ML/hardware work.
- Any phase-status update should be reflected back into the status table
  at the top of this file in the same change.
