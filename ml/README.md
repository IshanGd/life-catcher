# Crash-detection ML pipeline

Random Forest classifier over windowed 6-axis IMU data, per
`01_REQUIREMENTS.md` §4.3 and ADR-3 in `02_ARCHITECTURE.md`. Small,
interpretable, portable to the ESP32 via micromlgen/emlearn once it is
validated on real data.

## Pipeline shape (the contract)

```
generate_synthetic_data.py ─┐
loaders/<dataset>.py ───────┼─> {ax,ay,az,gx,gy,gz,label,window_id} CSV
                            │        (config.SCHEMA_COLUMNS)
                            └─> features.py ─> train_model.py ─> models/
```

- **Window:** 50 Hz, 2 s, 100 samples/window (`config.py`). Matches the
  ESP32 + MPU6050 target — the ported model is only valid for this shape.
- **Classes:** `normal_riding`, `pothole_bump`, `harsh_brake`,
  `crash_impact` — identical to the ML label set in `01_REQUIREMENTS.md`
  §4.3 and the `event_type` values in the BLE contract
  (`02_ARCHITECTURE.md` §4).
- **Units:** accel in g, gyro in deg/s. Loaders convert into these.
- **Features** (`features.py`): magnitude statistics (accel + gyro
  magnitude), jerk, signal magnitude area, FFT dominant frequency / energy,
  `g_recovery_ratio` (gyro magnitude first half vs. second half of the
  window — the crash-vs-pothole signal), per-axis means (sustained
  post-impact gravity rotation), and the raw first/second-half extrema.

## Reporting rule (`03_RULES.md` §3 — non-negotiable)

`train_model.py` refuses to finish without printing all three:

| metric | definition |
|---|---|
| **missed-crash rate** | `FN_crash / (all real crash windows)` = 1 − recall |
| **crash false-alarm rate** | `FP_crash / (all real non-crash windows)` = 1 − specificity |
| **crash false-discovery rate** | `FP_crash / (all windows predicted crash)` = 1 − precision |

Aggregate accuracy alone is not an acceptable report for this project.

## Usage

```bash
python -m pip install -r requirements.txt

# 1. synthetic scaffold (pipeline-mechanics check only)
python generate_synthetic_data.py --n-per-class 500
python train_model.py                       # provenance defaults to "synthetic"

# 2. real data (Phase 1)
#    - download DAMOTO into data/damoto/  (see data/damoto/README.md)
python -m loaders.damoto --describe          # confirm columns/units/layout first
python -m loaders.damoto                     # -> data/damoto_windows.csv
python train_model.py --data data/damoto_windows.csv \
    --provenance real --provenance-note "DAMOTO falls + <negatives>, 2026-09"
```

## Data provenance

`03_RULES.md` §3: every dataset added under `data/` is logged here with
source, type (synthetic / real / controlled-test), and label mapping.

| Dataset | Type | Location | Classes it provides | Notes |
|---|---|---|---|---|
| synthetic generator | **synthetic** | `data/synthetic/windows.csv` (git-ignored, regenerable) | all 4 | Separated by construction. `01_REQUIREMENTS.md` §4.3 **[LOCKED]** — validates pipeline mechanics, **not** field accuracy. No field-readiness claim may rest on it. |
| DAMOTO (Boubezoul et al. 2019, Data in Brief 23:103828 + corrigendum 30:105577, 2020) | real (controlled track, stuntman) | `data/damoto/` (git-ignored) — supplementary ZIPs on PMC, **not Mendeley**; see `data/damoto/README.md` | `crash_impact` (4 falls), `harsh_brake` (harsh-braking events), `normal_riding` (fall pre-roll + fall-like near-falls + calm) | **Loaded & verified 2026-09** via `loaders/damoto.py`. Format: tab-sep, latin-1, cols `time,Ax,Ay,Az` (m/s²) `,Rx,Ry,Rz` (deg/s), 1 kHz → decimated to 50 Hz. Corrigendum data used (original `Ay` was swapped). **accel rails at ±1.8 g and gyro at ±110 deg/s — both saturate in every fall.** Only 4 fall events; crash windows are dominated by the multi-second on-its-side aftermath, not the impact instant. `group` column = source event, so evaluation holds out whole falls. |
| DAMOTO "Much degraded track" | real (rough road) | `data/damoto/original_mmc2/` | `pothole_bump` | Continuous rough-road vibration used as the pothole/rough-road negative. From the **pre-corrigendum** file, so its `ay` is the buggy channel — `az`/magnitude carry the signal. A stand-in until real Indian-road pothole data exists. |
| _low-speed tip-over + Indian-road pothole data — still needed_ | — | — | realistic `crash_impact`, `pothole_bump` | Phase 1 note: SisFall / UMAFall / UP-Fall only for negative diversity, never a crash substitute. Controlled drop-tests (Phase 2) are the real fix for the crash class. |

## Results — first non-synthetic run (2026-09, `models/rf_crash_damoto.pkl`)

222 windows (crash 60 / harsh_brake 24 / normal 75 / pothole 63).
**Out-of-fold, group-aware** 3-fold CV (each of the 4 falls held out entirely
in turn — no window from a test fall is ever in training):

| metric | value |
|---|---|
| missed-crash rate (FN / all crash windows) | **0.00** (0 / 60), all 3 folds |
| crash false-alarm rate (FP / all non-crash) | **0.00** (0 / 162), all 3 folds |
| overall accuracy | 0.92 |
| harsh_brake recall | 0.54 (weak — crude braking-event detector, genuinely subtle vs normal) |

**Do not read this as field accuracy.** Per `01_REQUIREMENTS.md` §4.3
[LOCKED] and §7 risk #1, the number is not trustworthy because:

- Only **4 fall events**, all high-speed (~90 km/h) track falls with full
  rotation and 5+ s lying on the ground. The model keys on the *sustained
  gravity re-orientation* (`ay_std`, `ay_mean`, `az_mean` are the top
  features) — a large, easy, low-frequency signal that generalises trivially
  across those 4. It says nothing about the hard cases the product needs:
  the sub-second impact, **low-speed urban tip-overs** that don't fully
  rotate, or laying the bike down gently.
- `pothole_bump` is one recording from a different logger session, so the
  model may be separating *recordings*, not *phenomena*.
- No Indian-road potholes and no low-speed drops in the data at all.
- Both sensors saturate during the falls, so the impact transient itself is
  clipped away.

What it *does* show: the pipeline runs end-to-end on real data; the window
schema, the 1 kHz→50 Hz decimation, group-aware evaluation, and the
sustained-tilt features all work; and fall-like manoeuvres that recover are
**not** false-flagged as crashes (0 / 41). Next: controlled drop-tests once
hardware exists (Phase 2), and a real pothole source.

## Status

Phase 0 scaffold: **done**.
Phase 1: **first non-synthetic run done** (DAMOTO loaded, group-aware
evaluation, crash-class FN/FP documented above). The formal `04_PHASES.md`
exit criterion is met; the caveats above mean this is *not* a field-accuracy
claim. Still open for a trustworthy crash model: controlled drop-tests
(Phase 2), low-speed tip-over data, real pothole data.
