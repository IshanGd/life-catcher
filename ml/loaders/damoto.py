"""DAMOTO -> canonical window-schema adapter.

Source
------
"Dataset on powered two wheelers fall and critical events detection"
Boubezoul et al., Data in Brief 23 (2019) 103828. Collected under the French
ANR project DAMOTO (2008-2011).
  paper       : https://doi.org/10.1016/j.dib.2019.103828
  CORRIGENDUM : https://doi.org/10.1016/j.dib.2020.105577  (Data in Brief 30, 2020)

The data is NOT on Mendeley — it ships as supplementary ZIPs attached to the
articles:
  original article (PMC6660605): mmc2.zip (6 MB) + mmc3.zip (1.9 MB)
  corrigendum      (PMC7303291): mmc1.zip (6.4 MB)  <- USE THIS for the falls

Corrigendum: a binary->ASCII conversion bug in the original release swapped
the lateral-acceleration channel (Ay) with another sensor. The corrigendum
ZIP contains the corrected FALL datasets. The near-fall / extreme-manoeuvre
recordings were only in the original mmc2/mmc3 and may still carry the Ay
bug — treat those with caution (roll/yaw/pitch gyro is unaffected).

3D IMU (Bosch automotive sensor) on the motorcycle. Controlled-track
experiments: stuntman FALL trials (curve, slippery straight, roundabout,
intentional lean -- 4 recordings, each with a single labelled fall window,
see FALL_EVENTS_MS below) and professional-rider NEAR-FALL trials (zigzags,
extreme braking, accelerating manoeuvres, fall-like manoeuvres). Logging at
1 kHz with 4 us timestamping.

Known limits (matter for labelling and for comparing to our synthetic set):
  - Accelerometer range is only +/- 1.8 g -> real ground impact SATURATES.
    The fall signature here is tip-over rotation + sustained post-fall
    orientation, not a clean multi-g spike. Our synthetic crash_impact
    models 3-8 g spikes; do not expect the feature distributions to match.
  - Gyro spec quoted as "100 deg/s" -- confirm whether that is range or
    resolution against the real data (tip-over rates can exceed 100 deg/s).
  - Only 4 true fall recordings. The crash_impact class from DAMOTO alone is
    tiny; overlap-window it (crash_stride) and still expect to need
    controlled drop-tests (Phase 2) for a real crash set.

Why this is Phase 1's priority source (`04_PHASES.md`): it is real
two-wheeler-mounted accel+gyro data containing real falls / near-falls — the
closest available match to the crash / harsh-brake classes. SisFall / UMAFall
/ UP-Fall are only for negative-class diversity, never as a crash substitute.

Status
------
This adapter is written against the dataset *description* in the paper; the
exact CSV column order / units / file layout on Mendeley must be confirmed
against the downloaded files. Everything version-specific lives in
`DamotoConfig` so confirming it is a one-place edit. Run

    python -m loaders.damoto --describe

after downloading to print the real column names / rates / file tree, then
adjust the config and the SCENARIO_TO_LABEL map below.

`03_RULES.md` §3: any dataset added under `ml/data/` must be documented in
`ml/README.md` (source, synthetic/real/controlled, label mapping). Do that in
the same change that first runs this loader for real.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

from config import LABELS
from loaders.base import (
    RAW_AXES,
    finalize,
    resample_to_pipeline_fs,
    slice_windows,
    to_deg_s,
    to_g,
)

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "damoto"


@dataclass
class DamotoConfig:
    """Everything that depends on the exact Mendeley file layout / units.

    CONFIRM every field against the downloaded data before trusting a run.
    """

    # column name in the source CSV -> our canonical axis name
    column_map: dict[str, str] = field(
        default_factory=lambda: {
            "Ax": "ax", "Ay": "ay", "Az": "az",
            "Gx": "gx", "Gy": "gy", "Gz": "gz",
        }
    )
    accel_unit: str = "g"          # paper reports g for the accelerometers; CONFIRM
    gyro_unit: str = "deg/s"       # CONFIRM (could be rad/s)
    source_fs_hz: float = 1000.0   # ~1 kHz high-resolution logging; CONFIRM
    csv_sep: str = ","
    # substring in the file/dir name -> DAMOTO scenario key
    filename_scenario_hints: dict[str, str] = field(
        default_factory=lambda: {
            "fall": "fall",
            "chute": "fall",           # FR: "chute" = fall
            "curve": "fall_curve",
            "virage": "fall_curve",
            "slip": "fall_slippery",
            "rond": "fall_roundabout",
            "roundabout": "fall_roundabout",
            "brake": "near_fall_brake",
            "frein": "near_fall_brake",
            "accel": "near_fall_accel",
            "normal": "normal",
            "ride": "normal",
        }
    )


# Labelled fall windows from Table 1 of the paper (ms from start of recording).
# "start" = lowest crash-protector bobbin hits the ground; "end" = stuntman's
# hips hit the floor. Falls are labelled by TIMESTAMP inside a long recording,
# not per-file -- once the real filenames are known, map each fall file to its
# entry here and cut the crash_impact window around [start, end] (+ margin for
# the tip-over lead-in and the settled aftermath).
FALL_EVENTS_MS: dict[str, tuple[int, int]] = {
    "fall_slippery": (40132, 40428),
    "fall_lean": (34288, 34502),
    "fall_roundabout": (35876, 36160),
    "fall_curve": (43486, 43756),
}

# DAMOTO scenario key -> our 4-class label. `pothole_bump` is intentionally
# absent: DAMOTO has no pothole trials, so that negative class must come from
# another dataset (see `04_PHASES.md` Phase 1 + `ml/README.md`).
SCENARIO_TO_LABEL: dict[str, str] = {
    "fall": "crash_impact",
    "fall_curve": "crash_impact",
    "fall_slippery": "crash_impact",
    "fall_roundabout": "crash_impact",
    "near_fall_brake": "harsh_brake",
    "near_fall_accel": "normal_riding",   # hard accel != crash; treat as normal-ish
    "normal": "normal_riding",
}


def _scenario_for(path: Path, cfg: DamotoConfig) -> str | None:
    hay = str(path).lower()
    # longest hint match wins so "fall_curve" beats "fall"
    best: str | None = None
    for hint, scen in sorted(cfg.filename_scenario_hints.items(), key=lambda kv: -len(kv[0])):
        if hint in hay:
            best = scen
            break
    return best


def describe(data_dir: Path = DATA_DIR) -> None:
    """Print the real file tree + a peek at each CSV — run this after download."""
    if not data_dir.exists():
        raise SystemExit(f"{data_dir} does not exist. See ml/data/damoto/README.md")
    csvs = sorted(data_dir.rglob("*.csv")) + sorted(data_dir.rglob("*.txt"))
    if not csvs:
        raise SystemExit(f"no .csv/.txt files under {data_dir}. See its README.md")
    print(f"{len(csvs)} data file(s) under {data_dir}:\n")
    cfg = DamotoConfig()
    for p in csvs[:40]:
        rel = p.relative_to(data_dir)
        try:
            head = pd.read_csv(p, sep=cfg.csv_sep, nrows=3)
            cols = list(head.columns)
            n = sum(1 for _ in open(p)) - 1
        except Exception as e:  # noqa: BLE001 - diagnostic path
            print(f"  {rel}  <unreadable: {e}>")
            continue
        print(f"  {rel}")
        print(f"      rows~{n}  cols={cols}  scenario_guess={_scenario_for(p, cfg)}")


def load_recording(path: Path, cfg: DamotoConfig) -> pd.DataFrame:
    """One DAMOTO CSV -> 50 Hz DataFrame with columns RAW_AXES (g, deg/s)."""
    raw = pd.read_csv(path, sep=cfg.csv_sep)
    have = {src: dst for src, dst in cfg.column_map.items() if src in raw.columns}
    if len(have) != 6:
        raise ValueError(
            f"{path.name}: expected columns {list(cfg.column_map)} but found "
            f"{list(raw.columns)}. Edit DamotoConfig.column_map."
        )
    df = raw.rename(columns=have)[list(RAW_AXES)].astype(float)
    for c in ("ax", "ay", "az"):
        df[c] = to_g(df[c].to_numpy(), cfg.accel_unit)
    for c in ("gx", "gy", "gz"):
        df[c] = to_deg_s(df[c].to_numpy(), cfg.gyro_unit)
    return resample_to_pipeline_fs(df, cfg.source_fs_hz)


def build_windows(
    data_dir: Path = DATA_DIR,
    cfg: DamotoConfig | None = None,
    *,
    crash_stride: int = 25,
) -> pd.DataFrame:
    """All DAMOTO recordings -> one validated window frame.

    Crash recordings are windowed with overlap (`crash_stride`) because falls
    are rare; negatives use non-overlapping windows.
    """
    cfg = cfg or DamotoConfig()
    files = sorted(data_dir.rglob("*.csv"))
    if not files:
        raise SystemExit(
            f"no CSVs under {data_dir}. Download DAMOTO first — see "
            f"{data_dir / 'README.md'}."
        )
    frames: list[pd.DataFrame] = []
    wid = 0
    skipped: list[str] = []
    for p in files:
        scen = _scenario_for(p, cfg)
        label = SCENARIO_TO_LABEL.get(scen) if scen else None
        if label is None:
            skipped.append(p.name)
            continue
        rec = load_recording(p, cfg)
        stride = crash_stride if label == "crash_impact" else None
        wins = slice_windows(rec, label, start_window_id=wid, stride=stride)
        if len(wins):
            frames.append(wins)
            wid = int(wins["window_id"].max()) + 1
    if skipped:
        print(f"skipped {len(skipped)} file(s) with no scenario match: "
              f"{skipped[:8]}{' ...' if len(skipped) > 8 else ''}")
    df = finalize(frames)
    print(df.groupby("label")["window_id"].nunique().to_string())
    missing = set(LABELS) - set(df["label"].unique())
    if missing:
        print(f"\nNOTE: classes not present from DAMOTO alone: {sorted(missing)} "
              f"— add them from another dataset before training (see ml/README.md).")
    return df


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--describe", action="store_true",
                    help="inspect downloaded files and exit (do this first)")
    ap.add_argument("--data-dir", type=Path, default=DATA_DIR)
    ap.add_argument("--out", type=Path,
                    default=DATA_DIR.parent / "damoto_windows.csv")
    ap.add_argument("--crash-stride", type=int, default=25)
    args = ap.parse_args()

    if args.describe:
        describe(args.data_dir)
        return

    df = build_windows(args.data_dir, crash_stride=args.crash_stride)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.out, index=False)
    print(f"\nwrote {df['window_id'].nunique()} windows -> {args.out}")
    print("train with:  python train_model.py --data "
          f"{args.out} --provenance real --provenance-note 'DAMOTO ...'")


if __name__ == "__main__":
    main()
