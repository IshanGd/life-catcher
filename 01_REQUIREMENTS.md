# Smart Helmet — Project Requirements

> Status: living document. Reflects decisions made as of Aug 2026. Any change to
> a requirement marked **[LOCKED]** needs an explicit human decision, not an
> agent judgment call — see `03_RULES.md`.

## 1. Product summary

**Name:** Smart Helmet for Gig Driver Safety
**One-line pitch:** A budget helmet add-on that detects crashes via sensor
fusion, screens for impairment pre-ride, scores riding behavior, and relays
everything through the driver's own phone instead of onboard GPS/cellular
hardware.
**Target users:** Bike-taxi and delivery gig drivers in India (Uber, Rapido,
Zomato-style platforms).
**Go-to-market model [LOCKED]:** B2B2C — sell to platforms, fleet-leasing
companies, or insurers, not direct-to-driver retail. This shapes several
downstream requirements (fleet dashboard, device provisioning, per-fleet
branding) that a pure consumer product would not need.

## 2. Problem statement

- Gig drivers have high accident exposure from long hours in heavy urban
  two-wheeler traffic, plus a distinct personal-safety risk (robbery/assault)
  that generic consumer smart helmets don't address.
- Platforms are under public and regulatory pressure to visibly invest in
  driver welfare (e.g. Delhi-NCR driver protests, March 2026).
- The Indian helmet market is extremely price-sensitive — economy models are
  roughly half of the connected-helmet segment — so the product must be built
  to a strict bill-of-materials budget, not ported down from a premium Western
  design.

**Core design insight [LOCKED]:** value comes from stripping cost out by
offloading GPS, cellular connectivity, and heavier compute to the driver's
phone — which is already mounted, powered, and data-connected as a condition
of the job — rather than matching premium feature sets (AR/HUD, onboard
cellular modules, onboard GPS chips).

## 3. Users / personas

**There are exactly two dashboards in this product, and passengers are not a
user of either.** This is worth stating explicitly because it's a common
point of confusion: every sensor and screen in this product is physically
tied to the driver (helmet-worn detection, alcohol pre-ride check, panic
button, the phone the BLE pipeline runs through). There is no data path
where a passenger is involved — a passenger-safety feature (route-deviation
detection, unscheduled-stop alerts, e.g. Ola's "Guardian") is a different
product, built on different data (the platform's trip data, not helmet
telemetry), and is explicitly out of scope here. Do not conflate the two
when scoping new features.

| Persona | Dashboard | Needs |
|---|---|---|
| **Driver (primary)** | Driver companion app (built — see `05_DESIGN.md` §2) | Fast, low-friction pre-ride check; trustworthy crash detection with minimal false alarms; clear way to cancel a false SOS; visibility into their own safety score. |
| **Fleet/platform ops manager (B2B2C buyer)** | Fleet-Ops Dashboard (spec'd — see `05_DESIGN.md` §3), aggregate + per-driver drill-down | Fleet-wide compliance and risk visibility; device health monitoring; a bundle they can point to for the driver-welfare narrative; ability to drill into one driver's record for a coaching conversation when their score drops. |
| **Insurer claims processor (secondary buyer/partner)** | Fleet-Ops Dashboard, incident-level claims export view | Fast, objective reconstruction of a specific incident (timestamp, severity, GPS, sensor confirmation, SOS sent/cancelled) — this is a distinct, sellable feature (faster claims verification), not a side effect of the driver app's alert log. |
| **Customer support agent** | Fleet-Ops Dashboard, device-health-only scoped view | Troubleshoot a specific driver's device (battery, firmware, last sync, calibration age) without needing access to that driver's safety score or event history. |

These four personas share one underlying dataset but must see different,
permission-scoped slices of it — see `02_ARCHITECTURE.md` §7 for the access
model. Do not build a single undifferentiated "admin view" that shows
everything to everyone with a login.

## 4. Functional requirements

### 4.1 Helmet hardware unit

| Requirement | Detail | Priority |
|---|---|---|
| Crash/tilt detection | MPU6050 (accel + gyro) feeding a trained ML model, not fixed thresholds alone | Core |
| Impact confirmation | Piezo sensor as a second, independent signal — sensor fusion reduces false positives from potholes/drops | Core |
| Wear detection | FSR (force-sensitive resistor) confirms the helmet is actually being worn before arming ride-mode logic | Core |
| Connectivity | ESP32 (built-in BLE) — single chip for MCU + wireless, relays all data to the phone app | Core |
| Emergency messaging | Routed through the **phone's** data/SMS via BLE, not an onboard cellular module | Core — architecture decision, see `02_ARCHITECTURE.md` |
| Location | Routed through the **phone's** GPS via BLE, not an onboard GPS module | Core — architecture decision |
| False-alarm mitigation | Buzzer + physical cancel button; a 10-second "are you OK?" confirm window before SOS fires | Core |
| Personal safety | Physical panic button, independent of crash-detection logic, for robbery/assault scenarios | Core |
| Impairment screening | MQ-3 alcohol sensor + breath-sampling chamber, used as a one-time pre-ride "check-in" gate, not continuous monitoring | Core |
| BLE-link-down indicator | LED/buzzer signal so the driver knows if the phone link has silently dropped | Core (fallback for the phone-dependency trade-off) |

**Explicitly deferred / out of scope for MVP:**
- Heart rate / SpO2 sensing — helmet-mounted placement is unreliable for this
  sensor class; not worth the false confidence.
- Vehicle ignition interlock — liability/warranty/legal complexity of tapping
  a driver-owned vehicle's ignition circuit outweighs the benefit at this
  stage.
- Onboard cellular module (LTE-M/NB-IoT) — the correct long-term upgrade path
  *if* the phone-dependency assumption is ever removed (e.g. a premium or
  insurance-backed tier), but not justified for the MVP budget or
  certification burden.

### 4.2 Companion app (driver-facing, phone-side)

Screens and functionality are specified in detail in `05_DESIGN.md` against
the existing mockup. Functional scope:

- Live device status: helmet worn, pre-ride check passed, BLE link state,
  battery, firmware version.
- Safety score (daily + weekly trend), computed from harsh-braking,
  harsh-acceleration, and cornering-anomaly rates per 100 km using phone GPS +
  helmet accel data.
- Recent events feed and full alert history (harsh braking, impact
  alerts — including cancelled/false-positive ones, pre-ride check results,
  firmware sync, fatigue nudges, panic-button self-tests).
- Fatigue / shift-duration nudges (software-only, phone-side timer).
- Emergency contact management.
- Device pairing and device health (battery, last sync, firmware version,
  alcohol sensor calibration age).
- SOS relay: on a confirmed crash or panic-button press, use the phone's own
  GPS + data/SMS to notify the emergency contact (and, in a platform-
  integrated deployment, the platform's backend).

### 4.3 ML crash-detection pipeline

- Input: windowed 6-axis IMU data (accel x/y/z + gyro x/y/z) at 50 Hz,
  2-second windows (100 samples/window) — matches common ESP32+MPU6050
  setups.
- Classes: `normal_riding`, `pothole_bump`, `harsh_brake`, `crash_impact`.
- Feature set: magnitude statistics, jerk, signal magnitude area (SMA), FFT
  dominant frequency/energy, and `g_recovery_ratio` (gyro magnitude in the
  first vs. second half of the window — the key signal separating a crash,
  where the bike stays tipped over, from a pothole, which recovers).
- Model: Random Forest first, chosen deliberately over a deep model for size,
  interpretability, and ease of porting to a microcontroller (via
  micromlgen/emlearn, or Edge Impulse's pipeline for the production path).
- **Field-relevant metrics that matter more than raw accuracy:** missed-crash
  rate (false negatives on the crash class) and false-alarm rate (false
  positives on the crash class). Report both, not just aggregate accuracy.
- **[LOCKED — do not treat as done]** The current pipeline runs on
  **synthetic data only**. 100% accuracy on synthetic data is a pipeline-
  mechanics validation, not a real result — synthetic classes are cleanly
  separated by construction. Real data (Indian-road potholes, real hard
  braking, real low-speed drops) will overlap far more. No claim of
  field-ready accuracy may be made until real or controlled-drop-test data
  has been used.

### 4.4 Fleet-Ops Dashboard (spec'd — not yet built)

Full screen-by-screen design now exists in `05_DESIGN.md` §3. Functional
scope, organized by the three personas from §3 above:

**Fleet ops manager view:**
- Fleet-wide aggregates across the five metric families: safety (aggregate
  and per-driver scores, trend), compliance (helmet-wear rate, pre-ride
  checks completed), risk (harsh-event rates, crash/near-miss counts),
  fatigue (shift-duration patterns, nudge frequency), device health
  (battery, firmware version, sync recency, sensor calibration age).
- Per-driver drill-down into the same record the driver themself sees
  (same events, same score, same timeline) — this must mirror the driver
  app's data exactly, not a separately-computed summary, so a coaching
  conversation references numbers the driver recognizes.
- Fleet-level filtering/sorting to surface "which drivers/regions need
  intervention."

**Insurer claims processor view:**
- Incident-level export for a specific confirmed (non-cancelled) crash
  event: timestamp, severity score, GPS coordinates, which sensors
  confirmed it (fusion trail per ADR-4), and whether SOS was sent or
  cancelled. Framed explicitly as claims support, not a general safety
  score view — this is a distinct, sellable capability in its own right.

**Customer support view:**
- Device health only (battery, firmware, last sync, calibration age) for a
  specific device, scoped so support cannot see that driver's safety score
  or event history to do their job.

**[LOCKED — needs governance sign-off before build, see `06_GOVERNANCE.md`]**
Before any of these views ship, the policy question of what a fleet/platform
is allowed to *do* with a driver's safety score or a flagged pre-ride check
(coaching only vs. disciplinary/deactivation use) must be documented and
agreed with the first pilot partner. Do not treat this as a UI-only
feature — the access model and the usage policy are both requirements.

### 4.4a Continuous data flywheel [NEW — critical for pilot credibility]

The 10-second SOS cancel/confirm window (§4.1) is currently designed purely
as a false-alarm mitigation UX pattern. It is also, structurally, a live
source of driver-confirmed ground-truth labels (confirmed crash, cancelled/
false-positive, with the driver's own annotation e.g. "pothole") at the
exact moment ground truth is freshest.

**Requirement:** every confirm/cancel interaction must be captured as a
structured, labeled record and fed back into the ML retraining pipeline
(`ml/`), not just logged as a driver-facing app event. This turns "collect
real data" (the #1 open risk in §7) from a one-time pre-pilot hurdle into an
ongoing loop that keeps improving during and after the pilot — which is
also the actual defensible moat against a same-year competitor like AVRO
Helmets, who can copy the sensor list in a quarter but not months of
driver-confirmed field labels.

This requires its own explicit driver consent/disclosure, separate from the
core safety-feature consent — see `06_GOVERNANCE.md`.

### 4.5 Business / go-to-market requirements

**Revenue model [OPEN DECISION — resolve before first pilot pricing
conversation]:** not yet decided between (a) one-time hardware sale to
fleets, (b) a lease model, or (c) a lower-upfront-cost device paired with a
per-driver monthly subscription for the safety-analytics/Fleet-Ops-Dashboard
layer. Working hypothesis to validate, not a locked decision: **(c)**,
because it funds the continuous retraining loop in §4.4a on an ongoing
basis, aligns revenue with what an insurer actually wants (reduced claims,
not device count), and gives a natural expansion path into the Fleet-Ops
Dashboard once it's built. State this hypothesis explicitly in the first
pilot conversation rather than deferring the pricing question — "we haven't
decided" is a weaker position than a stated, revisable hypothesis.

**Future data product — hazard/hotspot mapping (explicitly NOT general
traffic prediction) [OPEN, longer-term, do not build now]:** aggregated
harsh-braking/near-miss/crash event locations could be packaged as a
road-safety hazard map — "which intersections produce the most dangerous
events" — sold to municipal road-safety authorities, urban planners, or
insurers for location-based risk pricing. This is explicitly **not** a
general traffic-flow/congestion prediction product: that market (INRIX,
HERE, TomTom, and ultimately Google/Waze) is saturated by incumbents
running tens-of-millions-of-vehicle crowd-sourced GPS-speed networks, and
this project's helmet accel/gyro signal adds nothing over the phone-GPS
speed data those incumbents already have at far greater scale. Do not
pursue general traffic prediction. The hazard-mapping angle is viable only
because it's a different signal (danger events tied to location, not
traffic speed/volume) that those incumbents don't optimize for — but it
requires its own third-party data-sharing consent path (see
`06_GOVERNANCE.md`) and should not be pursued before Phase 6 (pilot) has
produced enough location-dense event data to make a hazard map credible.
See `04_PHASES.md` for sequencing.

- Pilot-first rollout: a smaller partner (regional fleet-leasing company,
  city-level delivery aggregator, or an insurer underwriting gig-driver
  policies) before approaching large platforms directly.
- Pilot must generate real false-positive/negative rates, durability, and
  battery-life data — this is the evidence base for later platform
  conversations, not a formality.
- Differentiation to lead with: alcohol screening + ride behavior scoring +
  shift fatigue nudges bundled with crash detection — not currently offered
  as a bundle by Zomato (wear-compliance focus), Rapido (app-only panic
  button), Ola (passenger-safety focus), or AVRO Helmets (crash-detection +
  GPS, the closest direct competitor, same-year entrant).

## 5. Non-functional requirements

| Requirement | Target | Notes |
|---|---|---|
| BOM cost (sensors + MCU) | ~₹860–1,370 | Excludes battery/enclosure/helmet shell |
| All-in per-unit cost | ~₹1,500–2,500 | Incl. battery, enclosure, assembly |
| SOS false-alarm mitigation | 10-second cancel window | Applies to every auto-triggered SOS, no exceptions |
| Regulatory | No onboard cellular radio | By design — avoids India's ETA (Equipment Type Approval) telecom certification burden entirely |
| Alcohol sensor framing | Never described as a legal breathalyzer | MQ-3 is a chemo-resistive ethanol vapor sensor; liability framing must stay explicit in every pitch/spec/UI string |
| Alcohol sensor calibration | Per-unit, assembly-line step | Heater-based sensor drifts with storage; needs a clean-air baseline vs. alcohol-exposed reading per physical unit, not a firmware constant |
| BLE dependency | Must degrade visibly, not silently | If the phone link drops, the driver must be alerted via LED/buzzer on the helmet itself |
| Ignition control | None, ever | The helmet must never cut or gate vehicle ignition — keeps hardware out of vehicle-control liability entirely, even on an alcohol-sensor threshold exceedance |

## 6. Success metrics (for the pilot phase)

- Missed-crash rate and false-alarm rate from real or controlled-drop-test
  data (not synthetic).
- Helmet wear-rate and pre-ride-check completion rate across pilot drivers.
- Device uptime / BLE-link reliability in the field.
- Battery life under real shift-length usage.
- At least one documented fleet/insurer pilot conversation initiated.

## 7. Open risks (carried from progress tracking, Aug 2026)

Ordered by what actually gates progress — see `04_PHASES.md` for the phase
breakdown these map to:

1. **No field-validated ML crash-detection accuracy yet.** Real data now
   runs through the pipeline (DAMOTO — `ml/README.md` §Results, Sept 2026):
   0% missed / 0% false-alarm on the crash class, group-aware. But that
   rests on only 4 high-speed full-rotation track falls with saturated
   sensors, and one rough-road recording for potholes — it is **not** a
   field-accuracy number. Pilot pitch and insurer trust still depend on
   low-speed tip-over data, real Indian-road pothole data, and controlled
   drop-tests (blocked on the Phase 2 prototype).
2. **No physical prototype built yet.** Every hardware component is at
   "design," not "prototype" — nothing has been soldered/assembled.
3. **Alcohol sensor breath-chamber physical design is unresolved.** This is
   the one hardware piece with an open physical-design question (mouthpiece/
   hygiene), not just a wiring task.
4. **No pilot partner identified or approached.** The GTM path is defined but
   has zero real-world traction; this can run in parallel with hardware work.
5. **No data-use/consent governance policy exists yet.** What a fleet or
   platform is allowed to do with a driver's safety score or a flagged
   pre-ride check (coaching vs. disciplinary use) is undecided. This is a
   commercial risk, not just an ethical one: if the first real-world story
   to reach drivers is "the helmet got someone fired," it inverts the
   driver-welfare narrative this whole GTM strategy depends on. See
   `06_GOVERNANCE.md` — must be resolved with the first pilot partner,
   before that pilot's contract is signed, not during it.
6. **Revenue model undecided.** See §4.5 — a stated hypothesis exists
   (device + subscription) but is unvalidated.
