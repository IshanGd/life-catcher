# Smart Helmet — Architecture

## 1. System overview

```
┌─────────────────────────────────────────┐
│              HELMET UNIT                 │
│                                           │
│  MPU6050 (accel + gyro) ──┐              │
│  Piezo impact sensor  ────┼──> ESP32 ────┼──> BLE ──> Companion App
│  FSR (wear detection) ────┤     (MCU +   │        (driver's phone)
│  MQ-3 (alcohol, gated) ───┤    BLE radio)│
│  Panic button ─────────────┤              │
│  Buzzer (cancel/confirm) ─┘              │
└─────────────────────────────────────────┘

Companion App (phone-side) owns:
  - GPS (phone's own radio — faster time-to-first-fix than a NEO-6M module,
    which matters most exactly when it's needed: immediately post-accident)
  - Cellular data/SMS for SOS relay (phone's own SIM — no onboard cellular
    radio on the helmet)
  - Ride behavior scoring (helmet accel data + phone GPS)
  - Shift duration / fatigue nudges
  - Platform API integration (optional, B2B2C deployments only)

Fleet-Ops Dashboard (web, backend) owns:
  - Aggregated safety/compliance/risk/fatigue/device-health metrics per fleet
  - Not yet built — concept stage, see 04_PHASES.md
```

## 2. Key architecture decisions (ADR-style)

### ADR-1: Phone-offload for GPS and cellular [LOCKED]

**Decision:** The helmet carries no onboard GPS module (no NEO-6M) and no
onboard cellular module (no SIM800L). Location and SOS messaging both route
through the driver's phone over BLE.

**Why:**
- Removes two full BOM line items and their supporting power circuitry from
  the helmet entirely.
- Avoids India's ETA (Equipment Type Approval) telecom certification burden,
  since the helmet itself carries no cellular radio.
- Sidesteps 2G-sunset risk — SIM800L is 2G-only, and 2G networks are being
  phased out across India and are largely gone in the US/EU already.
- Phone GPS has a faster time-to-first-fix than a NEO-6M module, which
  matters most exactly when it's needed: immediately post-accident.

**Trade-off, stated honestly:** this design assumes the phone is powered, in
range, and connected. That's acceptable for the gig-driver target segment (a
job requirement), not necessarily for a general consumer product. Mitigation:
a BLE-link-down indicator (LED/buzzer) on the helmet itself so the driver
knows if the safety layer has silently disconnected — this is a requirement,
not an enhancement (see `01_REQUIREMENTS.md` §5).

**Do not revisit this decision** by re-adding NEO-6M/SIM800L without an
explicit human decision — see `03_RULES.md`. An onboard cellular module
remains the correct long-term path only if the phone-dependency assumption
itself needs removing (e.g. a premium/insurance-backed tier).

### ADR-2: ESP32 as the single on-helmet compute + radio chip

**Decision:** One ESP32-class MCU handles all sensor reads, on-device ML
inference (once ported), and BLE — no separate radio module.

**Why:** Lowest part count, built-in BLE, cheap, well-supported toolchain.

### ADR-3: Random Forest before any neural network

**Decision:** Validate the feature-extraction and labeling approach with a
Random Forest before investing in a neural network / Edge Impulse pipeline.

**Why:** Small, fast, interpretable (feature importances show which signals
actually matter), and easy to port to a microcontroller via tools like
micromlgen or emlearn once validated. A deep model is the deployment-stage
upgrade, not the validation-stage default.

### ADR-4: Sensor fusion, never a single-sensor trigger [LOCKED]

**Decision:** No crash/emergency decision may be made from a single sensor
in isolation. Crash confirmation requires MPU6050 signal **and** piezo
impact confirmation (and, post-fusion, the `g_recovery_ratio`-style
sustained-tilt signal that distinguishes a crash from a recovered pothole).

**Why:** This is the core false-positive mitigation strategy for the whole
product, and it is also the thing that makes the trust story work for
drivers, fleets, and insurers alike. This rule constrains firmware, the ML
label schema, and the app's event feed — new event types must specify which
signals fused to produce them.

### ADR-5: MQ-3 alcohol screening is a gated pre-ride check, not continuous monitoring

**Decision:** Alcohol sensing happens once, in an enclosed breath-sampling
chamber, triggered during a pre-ride "check-in" (post helmet-donning,
pre-"go online" status) — not as passive in-helmet ambient sensing.

**Why:** Passive ambient sensing is unreliable due to airflow dilution and
cross-reactivity with hand sanitizer, perfume, and other VOCs. A dedicated
sampling chamber with a breath tube is the only implementation that produces
a usable reading.

**Downstream constraint:** on a threshold exceedance, the system flags the
event to the companion app and, in platform-integrated deployments, to the
platform backend for a human/policy decision. **The helmet must never cut
vehicle ignition** — this keeps the hardware out of vehicle-control
liability entirely. See `03_RULES.md` for the non-negotiable version of this
rule.

### ADR-6: The confirm/cancel window is a data pipeline, not just a UX pattern

**Decision:** Every SOS confirm/cancel interaction (ADR-4's fusion trigger,
resolved by the driver) is captured as a structured, labeled training
example and fed back into `ml/`, in addition to being logged as a driver-
facing app event.

**Why:** This is the cheapest, freshest source of real ground-truth labels
the product will ever have — it's generated automatically by the exact
interaction already required for false-alarm mitigation (§`01_REQUIREMENTS.md`
§4.4a). Treating it as a one-off app log instead of a retraining input
wastes the single best data source available before a large-scale pilot
exists.

**Implementation implication:** the event schema in §4 below must carry
enough information (raw window reference or feature vector, not just the
human-readable label) to be usable as a training example, not just a
display string. Coordinate with `ml/features.py`'s window schema
(`{ax, ay, az, gx, gy, gz, label, window_id}`) so a confirmed/cancelled
field event can be appended to the same dataset shape used for synthetic
data, per `03_RULES.md` §3.

**Governance dependency:** this requires its own explicit driver consent,
separate from core safety-feature consent — see `06_GOVERNANCE.md`. Do not
wire this pipeline live before that consent flow exists.

## 3. Repository layout (recommended)

```
smart-helmet/
├── firmware/              # ESP32 C/C++ (Arduino or ESP-IDF)
│   ├── src/
│   │   ├── sensors/       # MPU6050, piezo, FSR, MQ-3 drivers
│   │   ├── ble/           # GATT service/characteristic definitions
│   │   ├── inference/     # ported ML model (ported from ml/models/)
│   │   └── main.cpp
│   └── platformio.ini
├── ml/                     # Python — crash-detection pipeline
│   ├── generate_synthetic_data.py
│   ├── features.py
│   ├── train_model.py
│   ├── models/             # trained .pkl artifacts
│   ├── data/                # raw + synthetic datasets (gitignored if large/real)
│   └── README.md
├── app/                    # Flutter companion app (driver-facing)
│   ├── lib/
│   │   ├── screens/         # Home, Trends, Alerts, Profile — see 05_DESIGN.md
│   │   ├── services/         # BLE data service (single seam to real hardware)
│   │   ├── models/
│   │   └── theme/
│   └── pubspec.yaml
├── fleet-dashboard/         # Web dashboard for fleet/platform ops (not yet built)
├── docs/                    # this document set + ADRs + mockups
│   ├── 01_REQUIREMENTS.md
│   ├── 02_ARCHITECTURE.md
│   ├── 03_RULES.md
│   ├── 04_PHASES.md
│   ├── 05_DESIGN.md
│   └── mockups/              # dashboard_mockup.html, progress_map.html
└── README.md
```

## 4. BLE data contract (helmet → app)

Firmware and app must agree on a versioned message schema so either side can
evolve independently. Recommended minimal v1 status payload (JSON over a BLE
GATT characteristic, or a packed binary equivalent if payload size becomes a
concern):

```json
{
  "schema": 1,
  "helmet_worn": true,
  "pre_ride_passed": true,
  "battery_pct": 78,
  "firmware": "1.4.2",
  "event": null
}
```

Event payload, sent on the same or a separate characteristic when the
fusion pipeline flags something:

```json
{
  "schema": 1,
  "event_type": "crash_impact",
  "severity_score": 84,
  "confirmed_by": ["mpu6050", "piezo"],
  "timestamp_device_ms": 1234567,
  "awaiting_cancel": true,
  "cancel_window_sec": 10
}
```

`event_type` values must match the ML label set in `01_REQUIREMENTS.md`
§4.3 (`normal_riding`, `pothole_bump`, `harsh_brake`, `crash_impact`) plus
`panic_button` and `alcohol_flag` for the two non-ML-triggered events.
The app is the source of truth for GPS coordinates and SOS dispatch — it
attaches its own location and dispatches via its own SIM once it receives a
confirmed (non-cancelled) event.

### Schema 1 — fields the firmware adds (additive, non-breaking)

The Phase 2 firmware (`firmware/src/core/ble_schema.*`) emits, on top of the
minimal shapes above:

- **status:** `ble_link` (bool) — so the app can show link state directly.
- **event lifecycle:** an SOS produces up to two follow-up notifications on
  the EVENT characteristic with the same `event_type`:
  - `{... "awaiting_cancel": false, "cancelled": true, "cancel_reason": "driver"}`
    when the driver cancels inside the window — this is logged, never
    dropped (`03_RULES.md` §2);
  - `{... "awaiting_cancel": false, "confirmed": true}` when the window
    elapses — the app dispatches SOS on this one.
  Non-emergency events (`pothole_bump`, `harsh_brake` for ride scoring) are
  sent once with `awaiting_cancel: false` and no follow-up.

These are additive, so `schema` stays `1`. The next **breaking** change
(removed/renamed/retyped field) bumps it to `2` and is recorded here.

### Phase 3 additions (also additive)

- **`confirmed_by: ["mq3"]`** on an `alcohol_flag` event
  (`firmware/src/core/preride_check.*`) — a single-sensor source by design
  (ADR-5 makes this a gate, not a fusion-confirmed emergency; it is never
  routed through the SOS confirm/cancel/dispatch lifecycle, so
  `awaiting_cancel`/`cancelled`/`confirmed` stay `false` on this event type).
- **`{"cmd":"start_check"}`** on the COMMAND characteristic — the app sends
  this post helmet-donning, before letting the driver go online, to start
  the pre-ride check-in.
- `pre_ride_passed` in `StatusPayload` now reflects the real check result
  instead of the Phase 2 stub.

## 5. Companion app data flow

The app's `HelmetDataService` (or equivalent) is the **single seam** between
hardware and UI: every screen consumes a `HelmetStatus` stream and a set of
history getters (rides/events, alerts, device health) from this one service.
Swapping simulated data for real BLE notifications, or a REST/local-DB
backend for the static history, should never require touching a screen file.
This mirrors the pattern already established in `app/lib/services/` — keep
it that way; see `03_RULES.md`.

## 6. Fleet-Ops Dashboard architecture

UI/screen spec is in `05_DESIGN.md` §3. Functional scope is in
`01_REQUIREMENTS.md` §4.4. This section covers the backend/data-access
shape.

- A backend aggregating per-driver events/scores from the companion app (or
  a platform-side relay, depending on integration model). It should read
  from the **same event records** the driver's own app displays — the
  Fleet-Ops Dashboard is a different view over one dataset, not a
  separately-computed summary. This matters directly for the fleet-manager
  drill-down use case: a coaching conversation needs to reference numbers
  the driver recognizes from their own app.
- Do not start building this before Phase 1 (real ML data) and Phase 2
  (physical prototype) are substantially underway — see `04_PHASES.md` for
  sequencing rationale. There's nothing real to aggregate yet, and building
  fleet aggregation before the real event schema is proven on hardware
  risks locking in a data model that doesn't match what the hardware
  actually produces.

## 7. Access model (permission tiers) [NEW]

Four personas share one underlying dataset (see `01_REQUIREMENTS.md` §3)
and must never be served through a single undifferentiated "admin" login.
Minimum required tiers:

| Tier | Can see | Cannot see |
|---|---|---|
| **Driver** | Their own full record (score, events, device health) | Any other driver's data |
| **Fleet ops manager** | Aggregate fleet metrics; per-driver drill-down (score, events, trend) for drivers in their fleet | Raw sensor windows / ML training data; other fleets' data |
| **Insurer claims processor** | Incident-level export for a specific confirmed crash event they're processing a claim for (timestamp, severity, GPS, sensor fusion trail, SOS sent/cancelled) | That driver's day-to-day safety score, unrelated event history, or any other driver's data |
| **Customer support agent** | Device health only (battery, firmware, last sync, calibration age) for the device they're troubleshooting | Safety score, event history, location data |

**Implementation rule:** enforce these as backend query scopes, not as
frontend show/hide — a support agent's API access must not be capable of
returning safety-score data even if a future UI change forgot to hide it.
This is a `03_RULES.md`-level requirement, not a nice-to-have.

Any new consumer of this data (e.g. a future hazard-mapping product
per `01_REQUIREMENTS.md` §4.5) needs its own row in this table and its own
consent path before it gets a data feed — see `06_GOVERNANCE.md`.
