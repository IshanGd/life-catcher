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
| DAMOTO (Boubezoul et al. 2019, Data in Brief 23:103828 + corrigendum 30:105577, 2020) | real (controlled track, stuntman) | `data/damoto/` (git-ignored) — supplementary ZIPs on PMC, **not Mendeley**; see `data/damoto/README.md` | `crash_impact` (4 falls), `harsh_brake` (extreme-braking near-falls), `normal_riding` | **Adapter not yet validated against downloaded files.** Use the corrigendum ZIP for falls (original `Ay` channel was swapped). Accel range only ±1.8 g (impact saturates). No pothole trials → `pothole_bump` from elsewhere. |
| _pothole / negative-diversity source — TBD_ | — | — | `pothole_bump`, negative diversity | Phase 1: SisFall / UMAFall / UP-Fall for negative-class diversity only, never as a crash substitute. Indian-road pothole data still needed. |

## Status

Phase 0 scaffold: **done** (synthetic generator + features + trainer +
schema validation runnable end to end).
Phase 1: **in progress** — DAMOTO adapter written, pending real files +
retrain + documented crash-class FN/FP rates on non-synthetic data
(`04_PHASES.md` Phase 1 exit criteria).
