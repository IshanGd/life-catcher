"""Synthetic IMU window generator — the pipeline's scaffolding contract.

`03_RULES.md` §3: do not delete or silently overwrite this file. `features.py`
and `train_model.py` are built against the `{ax, ay, az, gx, gy, gz, label,
window_id}` schema it emits. Real data gets an *adapter* (see `loaders/`) that
produces the same schema — the pipeline shape does not change to fit new data.

`01_REQUIREMENTS.md` §4.3 **[LOCKED — do not treat as done]**: a model that
scores well on this synthetic data has only had its *pipeline mechanics*
validated. The four classes here are separated by construction; real
Indian-road potholes, real hard braking, and real low-speed drops overlap far
more. No field-readiness claim may rest on synthetic results.

Physical model per class (units: accel in g, gyro in deg/s):

  normal_riding  gravity ~1g on -az, low-amplitude broadband road vibration,
                 small gyro sway.
  pothole_bump   normal baseline + a short (~0.1-0.4 s) sharp vertical spike
                 and pitch kick, then FULL recovery to the normal-riding
                 baseline within the window (the recovering-transient signal
                 that `g_recovery_ratio` is meant to catch).
  harsh_brake    sustained forward deceleration (negative ax, ~0.4-0.9 g) over
                 a large part of the window + a nose-dive pitch rate; partial
                 recovery, never a full spike.
  crash_impact   large multi-axis impact spike (3-8 g), high tip-over gyro
                 rates (100-400 deg/s), then a SUSTAINED abnormal state: the
                 gravity vector has rotated onto a different axis (helmet/bike
                 down) and the gyro goes quiet (settled on the ground). Second
                 half of the window does NOT look like normal riding.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from config import RANDOM_SEED, SAMPLE_RATE_HZ, WINDOW_SAMPLES
from schema import validate_window_frame

FS = SAMPLE_RATE_HZ
N = WINDOW_SAMPLES
T = np.arange(N) / FS  # per-window time vector, seconds


def _road_vibration(rng: np.random.Generator, amp: float) -> np.ndarray:
    """Broadband-ish low-amplitude noise standing in for road texture."""
    white = rng.normal(0.0, amp, N)
    # a couple of low-frequency components (engine / road undulation)
    f1, f2 = rng.uniform(1.5, 4.0), rng.uniform(6.0, 12.0)
    slow = 0.4 * amp * np.sin(2 * np.pi * f1 * T + rng.uniform(0, 2 * np.pi))
    slow += 0.25 * amp * np.sin(2 * np.pi * f2 * T + rng.uniform(0, 2 * np.pi))
    return white + slow


def _normal_window(rng: np.random.Generator) -> dict[str, np.ndarray]:
    a_amp = rng.uniform(0.03, 0.09)
    g_amp = rng.uniform(2.0, 7.0)
    ax = _road_vibration(rng, a_amp)
    ay = _road_vibration(rng, a_amp)
    az = -1.0 + _road_vibration(rng, a_amp)  # gravity on -z, helmet upright
    gx = _road_vibration(rng, g_amp)
    gy = _road_vibration(rng, g_amp)
    gz = _road_vibration(rng, g_amp * 0.6)
    # gentle steering / lane changes
    if rng.random() < 0.5:
        c = rng.integers(10, N - 10)
        w = rng.integers(8, 25)
        lean = rng.uniform(-15, 15) * np.exp(-0.5 * ((np.arange(N) - c) / w) ** 2)
        gx += lean
    return dict(ax=ax, ay=ay, az=az, gx=gx, gy=gy, gz=gz)


def _pothole_window(rng: np.random.Generator) -> dict[str, np.ndarray]:
    base = _normal_window(rng)
    onset = int(rng.uniform(0.15, 0.55) * N)  # spike lands in the first half
    width = rng.integers(2, 7)  # 40-140 ms
    idx = np.arange(N)
    bump = np.exp(-0.5 * ((idx - onset) / width) ** 2)
    az_spike = rng.uniform(1.8, 4.5) * rng.choice([-1.0, 1.0])
    base["az"] = base["az"] + az_spike * bump
    base["ax"] = base["ax"] + rng.uniform(0.3, 1.2) * bump * rng.choice([-1, 1])
    base["gy"] = base["gy"] + rng.uniform(60, 180) * bump * rng.choice([-1, 1])
    base["gx"] = base["gx"] + rng.uniform(30, 90) * bump * rng.choice([-1, 1])
    # brief ring-down then back to the normal baseline (already present) -> the
    # second half of the window recovers.
    return base


def _harsh_brake_window(rng: np.random.Generator) -> dict[str, np.ndarray]:
    base = _normal_window(rng)
    start = int(rng.uniform(0.05, 0.35) * N)
    end = int(rng.uniform(0.7, 1.0) * N)
    ramp = np.zeros(N)
    ramp[start:end] = np.hanning(2 * (end - start))[: end - start]  # smooth rise
    decel = rng.uniform(0.4, 0.9)
    base["ax"] = base["ax"] - decel * ramp                # forward deceleration
    base["az"] = base["az"] + rng.uniform(0.1, 0.35) * ramp  # weight transfer
    base["gy"] = base["gy"] + rng.uniform(20, 70) * ramp  # nose-dive pitch rate
    return base


def _crash_window(rng: np.random.Generator) -> dict[str, np.ndarray]:
    base = _normal_window(rng)
    idx = np.arange(N)
    impact = int(rng.uniform(0.15, 0.45) * N)
    width = rng.integers(2, 6)
    spike = np.exp(-0.5 * ((idx - impact) / width) ** 2)

    mag = rng.uniform(3.0, 8.0)
    for k in ("ax", "ay", "az"):
        base[k] = base[k] + mag * rng.uniform(0.4, 1.0) * rng.choice([-1, 1]) * spike

    # violent tip-over rates around the impact
    tip = np.exp(-0.5 * ((idx - impact) / (width * 2.5)) ** 2)
    for k in ("gx", "gy", "gz"):
        base[k] = base[k] + rng.uniform(120, 400) * rng.choice([-1, 1]) * tip

    # SUSTAINED aftermath: from shortly after impact to end of window the bike
    # is down. Gravity rotates onto a horizontal axis; gyro goes quiet.
    settle = impact + rng.integers(3, 12)
    settle = min(settle, N - 1)
    down_axis = rng.choice(["ax", "ay"])
    sign = rng.choice([-1.0, 1.0])
    for k in ("ax", "ay", "az", "gx", "gy", "gz"):
        seg = slice(settle, N)
        if k == down_axis:
            base[k][seg] = sign * 1.0 + rng.normal(0, 0.05, N - settle)
        elif k == "az":
            base[k][seg] = rng.normal(0, 0.1, N - settle)  # no longer vertical
        elif k == "ax" or k == "ay":
            base[k][seg] = rng.normal(0, 0.08, N - settle)
        else:  # gyro: near-still on the ground
            base[k][seg] = rng.normal(0, 3.0, N - settle)
    return base


GENERATORS = {
    "normal_riding": _normal_window,
    "pothole_bump": _pothole_window,
    "harsh_brake": _harsh_brake_window,
    "crash_impact": _crash_window,
}


def generate(n_per_class: int, seed: int = RANDOM_SEED) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    frames: list[pd.DataFrame] = []
    wid = 0
    for label, fn in GENERATORS.items():
        for _ in range(n_per_class):
            w = fn(rng)
            frame = pd.DataFrame(
                {
                    "ax": w["ax"], "ay": w["ay"], "az": w["az"],
                    "gx": w["gx"], "gy": w["gy"], "gz": w["gz"],
                }
            )
            frame["label"] = label
            frame["window_id"] = wid
            frames.append(frame)
            wid += 1
    df = pd.concat(frames, ignore_index=True)
    return validate_window_frame(df)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--n-per-class", type=int, default=500)
    ap.add_argument("--seed", type=int, default=RANDOM_SEED)
    ap.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).parent / "data" / "synthetic" / "windows.csv",
    )
    args = ap.parse_args()

    df = generate(args.n_per_class, args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.out, index=False)
    n_win = df["window_id"].nunique()
    print(f"wrote {len(df):,} rows / {n_win:,} windows to {args.out}")
    print(df.groupby("label")["window_id"].nunique().to_string())
    print(
        "\nNOTE: synthetic data only. Per 01_REQUIREMENTS.md 4.3 this validates "
        "pipeline mechanics, not field accuracy."
    )


if __name__ == "__main__":
    main()
