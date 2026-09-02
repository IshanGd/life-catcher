# Smart Helmet — Rules for Claude Code

These rules govern how an AI coding agent should work on this repository.
They exist because this is a safety-relevant product with legal and
liability exposure (crash detection, emergency alerts, alcohol screening) —
not because of generic caution. Read `01_REQUIREMENTS.md` and
`02_ARCHITECTURE.md` before making non-trivial changes.

## 1. Decisions that require an explicit human sign-off

Do not change the following without the human explicitly asking for it and
confirming the trade-off. Flag the tension and stop instead of "fixing" it
silently:

- **Architecture ADRs in `02_ARCHITECTURE.md`** (phone-offload GPS/cellular,
  ESP32-only radio, RF-before-NN, sensor-fusion-only crash confirmation,
  gated pre-ride alcohol check). These were made deliberately against
  alternatives that look simpler; do not revert to the simpler alternative
  (e.g. adding a NEO-6M/SIM800L back in, or triggering SOS off a single
  accelerometer threshold) because it seems easier to implement.
- **The 10-second SOS cancel window.** Never remove it, shorten it below a
  value a human confirms, or make it skippable via a code path.
- **Ignition control.** Never add any code path — firmware, app, or backend —
  that allows the helmet or app to cut, gate, or delay vehicle ignition
  based on any sensor reading, including the alcohol sensor. This is a
  hard boundary, not a configuration option.
- **Alcohol sensor framing in any user-facing string, log, or doc.** Never
  describe the MQ-3 reading as a "breathalyzer test," "BAC measurement," or
  anything implying legal/forensic accuracy. It is an ethanol-vapor screen
  used for an internal pre-ride gate.
- **ML performance claims.** Never state or imply the crash-detection model
  is "field-validated," "production-accuracy," or similar while training
  data is synthetic-only. Check `ml/README.md` / `01_REQUIREMENTS.md` §4.3
  for current data provenance before writing any accuracy claim into docs,
  UI copy, or pitch material.
- **BOM/cost targets** in `01_REQUIREMENTS.md` §5. If an implementation
  choice would break the cost target, say so explicitly rather than quietly
  picking a pricier component.

## 2. Safety-critical engineering rules

- **No single-sensor emergency triggers.** Every crash/impact decision in
  firmware or ML inference must be fusion-based (ADR-4). If you're adding a
  new event type, state which sensors confirm it.
- **Fail visibly, not silently.** Any loss of BLE link, GPS fix, or sensor
  read must surface to the driver (LED/buzzer on-device, or a clear banner
  in-app) rather than degrading quietly. Model this on the existing
  "helmet not worn" banner pattern in the companion app.
- **Every auto-triggered emergency action must be cancellable** within its
  confirm window, and the cancellation must be logged as an event (not
  silently discarded) — fleets and insurers need false-positive rates, and
  that data only exists if cancellations are recorded.
- **Per-unit calibration steps (e.g. MQ-3) are assembly-line requirements,
  not firmware constants.** If you're touching alcohol-sensor code, keep the
  calibration baseline configurable per device, not hardcoded.

## 3. Data provenance & labeling rules (ML)

- Any new dataset added to `ml/data/` must be documented in `ml/README.md`
  with: source, whether it's synthetic/real/controlled-test, and which
  label set it maps to.
- Do not delete or silently overwrite `generate_synthetic_data.py` — it's
  the scaffolding contract that `features.py` and `train_model.py` are
  built against. If real data has a different shape, write an adapter that
  produces the same `{ax, ay, az, gx, gy, gz, label, window_id}` schema
  rather than reshaping the whole pipeline.
- Report both aggregate accuracy **and** crash-class false-negative/false-
  positive rates for every model evaluation. Aggregate accuracy alone is
  not an acceptable report for this project (see `01_REQUIREMENTS.md` §4.3).

## 4. Code organization rules

- Respect the seam in `02_ARCHITECTURE.md` §5: the companion app's data
  service (e.g. `HelmetDataService`) is the only place that should know
  whether data is simulated, BLE-sourced, or backend-sourced. Screens and
  widgets consume its stream/getters only.
- Firmware sensor drivers live under `firmware/src/sensors/`, one file per
  sensor, mirroring the hardware table in `01_REQUIREMENTS.md` §4.1.
- Keep the BLE message schema versioned (`"schema": N`) as described in
  `02_ARCHITECTURE.md` §4. Bump the version on any breaking field change and
  note it in that file — don't just change the shape in place.

## 5. Documentation rules

- When a component moves between phases (see `04_PHASES.md`), update its
  status there — don't let the phases doc drift from reality.
- Any new competitive/market claim must be dated (competitive landscape
  moves fast in this space — AVRO Helmets was a same-year entrant as of
  writing).
- Keep `01_REQUIREMENTS.md` §7 (open risks) current — if a risk is
  resolved, move it to a "resolved" note with how, rather than deleting it.

## 6. Definition of done (per feature)

A feature/PR is done when:
1. It matches an explicit requirement in `01_REQUIREMENTS.md`, or the human
   has explicitly asked for something outside that scope.
2. It doesn't violate any rule in this file.
3. If it touches the crash-detection or emergency-alert path: it has a
   cancellation path, it's logged, and it's fusion-based.
4. If it touches the ML pipeline: it reports crash-class false-positive/
   false-negative rates, not just accuracy.
5. Docs in this `docs/` set are updated if the change affects architecture,
   requirements, or phase status — not left to drift.
