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
  original article (PMC6660605): mmc2.zip (extreme manoeuvres) + mmc3.zip (falls)
  corrigendum      (PMC7303291): mmc1.zip = Corrected_DataSet_DataInBrief/
                                 (both falls AND extreme manoeuvres, corrected)

Corrigendum: a binary->ASCII conversion bug in the original release swapped
the lateral-acceleration channel (Ay) with another sensor. Use the
corrigendum data for everything it contains. The only recording NOT in the
corrigendum is "Much degraded track" (original mmc2) — used here for the
`pothole_bump` class, where the vertical axis carries the signal, but its
`ay` is still the buggy channel (documented in ml/data/damoto/README.md).

Confirmed file format (from each folder's ReadMe_V1.txt, verified against the
CSVs):
  - tab-separated, latin-1, one header row, ~10 trailing empty columns
  - col 0: time (s)      cols 1-3: Ax,Ay,Az (m/s^2)   cols 4-6: Rx,Ry,Rz (deg/s)
  - 1000 Hz (dt = 1.000 ms); first ~24 samples are zero (pre-trigger pad)
  - accel rails at ~+/-19 m/s^2 (+/-1.8 g Coriolis range) and gyro at
    +/-110 deg/s -- BOTH saturate during the falls. The usable fall signature
    is the tip-over rotation and the *sustained* post-fall orientation
    (gravity moves from az~+9.8 upright to ay~-8 on-its-side), not a clean
    multi-g impact spike. Our synthetic crash_impact models unclipped 3-8 g
    spikes -> do not expect the feature distributions to line up.

Only 4 true fall recordings exist (one labelled fall each, timestamps in
FALL_EVENTS_MS from Table 1 of the paper). The crash class from DAMOTO alone
is small; controlled drop-tests (Phase 2) are still needed. SisFall / UMAFall
/ UP-Fall are only for negative-class diversity, never a crash substitute.

`03_RULES.md` §3: this dataset + its label mapping are documented in
`ml/README.md` and `ml/data/damoto/README.md`.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

from config import LABELS, SAMPLE_RATE_HZ, WINDOW_SAMPLES
from loaders.base import RAW_AXES, finalize, resample_to_pipeline_fs, slice_windows, to_g

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "damoto"
FS = SAMPLE_RATE_HZ


@dataclass
class DamotoConfig:
    """Everything that depends on the exact file layout / units.

    Defaults match the corrigendum CSVs as verified 2026-09. Columns are read
    by POSITION, not header name — the real headers are mojibake
    (``Ax(m/s²)`` etc. in latin-1) and one is misspelled (``Ry.``).
    """

    sep: str = "\t"
    encoding: str = "latin-1"
    # 0-based source column indices: time, then accel x/y/z, then gyro x/y/z
    col_time: int = 0
    cols_accel: tuple[int, int, int] = (1, 2, 3)
    cols_gyro: tuple[int, int, int] = (4, 5, 6)
    accel_unit: str = "m/s^2"
    gyro_unit: str = "deg/s"
    source_fs_hz: float = 1000.0
    trim_leading_zero_rows: bool = True


# Labelled fall windows from Table 1 of the paper (ms from start of recording).
# start = lowest crash-protector bobbin hits the ground; end = stuntman's hips
# hit the floor. Verified against gyro-activity onset in the CSVs.
FALL_EVENTS_MS: dict[str, tuple[int, int]] = {
    "fall_slippery": (40132, 40428),
    "fall_lean": (34288, 34502),
    "fall_roundabout": (35876, 36160),
    "fall_curve": (43486, 43756),
}

# margins (seconds) around the labelled fall for the crash_impact window span
CRASH_LEAD_S = 1.0     # tip-over lead-in before the bobbin hits
CRASH_TRAIL_S = 5.0    # settled-on-the-ground aftermath (the strong sustained cue)


def _fall_key(path: Path) -> str | None:
    name = path.stem.lower()
    if "slippery" in name:
        return "fall_slippery"
    if "leaning" in name:
        return "fall_lean"
    if "roundabout" in name:
        return "fall_roundabout"
    if "curve" in name and "fall in" in name:
        return "fall_curve"
    return None


# ---------------------------------------------------------------------------
# The label plan. Each entry: which files, which part of them, what label,
# and how densely to window it. Kept as data so it's auditable and tweakable
# without touching logic. Paths are matched as case-insensitive substrings of
# the file path relative to the data dir.
# ---------------------------------------------------------------------------
@dataclass
class Rule:
    match: str
    label: str
    region: str          # "fall_span" | "pre_fall" | "brake_events" | "quiet" | "all"
    stride_s: float       # window hop; < 2.0 => overlapping
    keep_every: int = 1    # subsample the resulting windows (class balance)
    n_groups: int = 3      # split this (rule, file)'s windows into this many
                           # contiguous groups for event-aware CV; overlapping
                           # windows within a group never straddle a fold
    note: str = ""


# match strings are scoped to the CORRECTED data so the buggy original
# mmc2/mmc3 copies (also on disk) are never picked up -- except "much
# degraded track", which only exists in mmc2.
_CORR = "corrected_dataset_datainbrief/"
LABEL_PLAN: list[Rule] = [
    # --- crash_impact: the 4 corrected falls, tight overlap around the event
    Rule(_CORR + "falls scenarios/", "crash_impact", "fall_span", stride_s=0.30,
         n_groups=1,  # 1 group per fall file => 4 crash groups total; grouped
                      # CV then holds out a WHOLE unseen fall each fold
         note="[fall_start-1s, fall_end+5s]; accel+gyro clipped, tip-over + "
              "sustained on-side orientation carry it"),
    # --- normal_riding: calm lead-in of each fall recording
    Rule(_CORR + "falls scenarios/", "normal_riding", "pre_fall", stride_s=2.0,
         keep_every=3, note="[3s, fall_start-4s] of the fall files"),
    # --- harsh_brake: detected braking events in the harsh-braking recording
    Rule(_CORR + "extreme manoeuvres/harsh breaking", "harsh_brake", "brake_events",
         stride_s=0.30, note="sustained forward-decel (ax) excursions +/-1s"),
    Rule(_CORR + "extreme manoeuvres/harsh breaking", "normal_riding", "quiet",
         stride_s=2.0, keep_every=4, note="calm stretches of the same file"),
    # --- normal_riding hard negatives: near-falls that recover
    Rule(_CORR + "extreme manoeuvres/fall like manoeuvre", "normal_riding", "all",
         stride_s=2.0, keep_every=5,
         note="fall-like manoeuvres that DID NOT become falls - hardest negatives"),
    # --- pothole_bump: rough-road recording (only in the buggy original;
    #     vertical axis carries it, ay is the bugged channel - see README)
    Rule("much degraded track", "pothole_bump", "all", stride_s=1.0, keep_every=2,
         note="continuous rough-road vibration; original mmc2, ay still buggy"),
    # "Acceleration On Curve/Straight Line" are deliberately unused: hard
    # acceleration has no matching class in the 4-label set.
]


# ---------------------------------------------------------------------------
def _read_raw(path: Path, cfg: DamotoConfig) -> pd.DataFrame:
    """One DAMOTO CSV -> raw 1 kHz DataFrame [ax,ay,az,gx,gy,gz] in g / deg/s."""
    use = [cfg.col_time, *cfg.cols_accel, *cfg.cols_gyro]
    raw = pd.read_csv(
        path, sep=cfg.sep, encoding=cfg.encoding, header=0,
        usecols=use, names=["t", *RAW_AXES], engine="python", on_bad_lines="skip",
    )
    df = raw.apply(pd.to_numeric, errors="coerce").dropna().reset_index(drop=True)
    if cfg.trim_leading_zero_rows:
        nz = np.flatnonzero(df[list(RAW_AXES)].abs().to_numpy().sum(axis=1) > 1e-6)
        if len(nz):
            df = df.iloc[nz[0] :].reset_index(drop=True)
    for c in ("ax", "ay", "az"):
        df[c] = to_g(df[c].to_numpy(float), cfg.accel_unit)
    # gyro already deg/s
    return df[list(RAW_AXES)]


def load_recording(path: Path, cfg: DamotoConfig) -> pd.DataFrame:
    """Raw CSV -> 50 Hz DataFrame [ax..gz] (anti-aliased decimation from 1 kHz)."""
    return resample_to_pipeline_fs(_read_raw(path, cfg), cfg.source_fs_hz)


def _detect_brake_events(rec: pd.DataFrame) -> list[tuple[int, int]]:
    """Return [start, end] sample spans of sustained forward deceleration.

    Forward axis is ax (verified: harsh-braking file shows +/-0.75 g on ax,
    < 0.35 g on ay). Threshold on a 0.3 s rolling mean, keep runs >= 0.3 s.
    """
    ax = pd.Series(rec["ax"].to_numpy()).rolling(int(0.3 * FS), center=True).mean()
    hot = (ax.abs() > 0.35).fillna(False).to_numpy()
    spans: list[tuple[int, int]] = []
    i, n, min_len = 0, len(hot), int(0.3 * FS)
    while i < n:
        if hot[i]:
            j = i
            while j < n and hot[j]:
                j += 1
            if j - i >= min_len:
                spans.append((i, j))
            i = j
        else:
            i += 1
    return spans


def _windows_from_span(rec: pd.DataFrame, label: str, lo: int, hi: int,
                       start_wid: int, stride_s: float) -> pd.DataFrame:
    lo = max(0, lo)
    hi = min(len(rec), hi)
    if hi - lo < WINDOW_SAMPLES:
        return pd.DataFrame(columns=[*RAW_AXES, "label", "window_id"])
    stride = max(1, int(round(stride_s * FS)))
    seg = rec.iloc[lo:hi].reset_index(drop=True)
    return slice_windows(seg, label, start_window_id=start_wid, stride=stride)


def _regions_for(rule: Rule, path: Path, rec: pd.DataFrame) -> list[tuple[int, int]]:
    n = len(rec)
    if rule.region == "all":
        return [(int(3 * FS), n - int(3 * FS))]
    if rule.region == "fall_span":
        key = _fall_key(path)
        if key is None or key not in FALL_EVENTS_MS:
            return []
        s_ms, e_ms = FALL_EVENTS_MS[key]
        return [(int((s_ms / 1000 - CRASH_LEAD_S) * FS),
                 int((e_ms / 1000 + CRASH_TRAIL_S) * FS))]
    if rule.region == "pre_fall":
        key = _fall_key(path)
        if key is None:
            return []
        s_ms = FALL_EVENTS_MS[key][0]
        return [(int(3 * FS), int((s_ms / 1000 - 4.0) * FS))]
    if rule.region == "brake_events":
        return [(max(0, s - FS), e + FS) for s, e in _detect_brake_events(rec)]
    if rule.region == "quiet":
        hot = np.zeros(n, dtype=bool)
        for s, e in _detect_brake_events(rec):
            hot[max(0, s - 2 * FS) : e + 2 * FS] = True
        # contiguous cool runs
        runs, i = [], 0
        while i < n:
            if not hot[i]:
                j = i
                while j < n and not hot[j]:
                    j += 1
                runs.append((i, j))
                i = j
            else:
                i += 1
        return runs
    raise ValueError(f"unknown region {rule.region!r}")


def build_windows(data_dir: Path = DATA_DIR, cfg: DamotoConfig | None = None) -> pd.DataFrame:
    cfg = cfg or DamotoConfig()
    files = sorted(data_dir.rglob("*.csv"))
    if not files:
        raise SystemExit(
            f"no CSVs under {data_dir}. Download DAMOTO first — see "
            f"{data_dir / 'README.md'}."
        )

    frames: list[pd.DataFrame] = []
    wid = 0
    per_rule: dict[str, int] = {}
    rec_cache: dict[Path, pd.DataFrame] = {}

    for rule in LABEL_PLAN:
        for path in files:
            rel = str(path.relative_to(data_dir)).lower().replace("\\", "/")
            if rule.match not in rel:
                continue
            rec = rec_cache.get(path)
            if rec is None:
                rec = rec_cache[path] = load_recording(path, cfg)
            made: list[pd.DataFrame] = []
            for lo, hi in _regions_for(rule, path, rec):
                w = _windows_from_span(rec, rule.label, lo, hi, wid, rule.stride_s)
                if len(w):
                    made.append(w)
                    wid = int(w["window_id"].max()) + 1
            if not made:
                continue
            block = pd.concat(made, ignore_index=True)
            if rule.keep_every > 1:
                keep_ids = block["window_id"].drop_duplicates().iloc[:: rule.keep_every]
                block = block[block["window_id"].isin(keep_ids)]

            # event-aware group id: split this (rule, file)'s ordered windows
            # into up to n_groups contiguous chunks
            ordered = list(block["window_id"].drop_duplicates())
            k = max(1, min(rule.n_groups, len(ordered)))
            stem = path.stem.lower().replace(" ", "_")[:24]
            chunk_of = {
                w: f"{rule.label}:{stem}:{ci}"
                for ci, chunk in enumerate(np.array_split(ordered, k))
                for w in chunk
            }
            block["group"] = block["window_id"].map(chunk_of)

            frames.append(block)
            key = f"{rule.label}<-{rule.match}"
            per_rule[key] = per_rule.get(key, 0) + block["window_id"].nunique()

    df = finalize(frames)
    print("windows per rule:")
    for k, v in per_rule.items():
        print(f"  {v:5d}  {k}")
    print("\nwindows per label:")
    print(df.groupby("label")["window_id"].nunique().to_string())
    missing = set(LABELS) - set(df["label"].unique())
    if missing:
        print(f"\nNOTE: no windows for {sorted(missing)} from DAMOTO — add from "
              f"another dataset before training (see ml/README.md).")
    return df


def describe(data_dir: Path = DATA_DIR) -> None:
    cfg = DamotoConfig()
    paths = sorted(data_dir.rglob("*.csv")) + sorted(data_dir.rglob("*.txt"))
    if not paths:
        raise SystemExit(f"no data files under {data_dir}. See {data_dir/'README.md'}")
    print(f"{len(paths)} file(s) under {data_dir}:\n")
    for p in paths:
        rel = p.relative_to(data_dir)
        if p.suffix == ".txt":
            print(f"  {rel}  (readme)")
            continue
        try:
            rec = load_recording(p, cfg)
            a = rec[["ax", "ay", "az"]].to_numpy()
            g = rec[["gx", "gy", "gz"]].to_numpy()
            print(f"  {rel}")
            print(f"      50Hz rows={len(rec)} ({len(rec)/FS:.0f}s)  "
                  f"accel g[{a.min():.1f},{a.max():.1f}]  gyro d/s[{g.min():.0f},{g.max():.0f}]  "
                  f"fall_key={_fall_key(p)}")
        except Exception as e:  # noqa: BLE001 - diagnostic
            print(f"  {rel}  <unreadable: {e}>")


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--describe", action="store_true",
                    help="inspect downloaded files (ranges, fall keys) and exit")
    ap.add_argument("--data-dir", type=Path, default=DATA_DIR)
    ap.add_argument("--out", type=Path, default=DATA_DIR.parent / "damoto_windows.csv")
    args = ap.parse_args()

    if args.describe:
        describe(args.data_dir)
        return

    df = build_windows(args.data_dir)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.out, index=False)
    print(f"\nwrote {df['window_id'].nunique()} windows -> {args.out}")
    print("next:  python train_model.py --data "
          f"{args.out.name and args.out} --provenance real "
          "--provenance-note 'DAMOTO corrigendum falls + harsh-braking + "
          "fall-like negatives + degraded-track potholes'")


if __name__ == "__main__":
    main()
