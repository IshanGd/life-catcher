"""Shared building blocks for real-data loaders: resampling and windowing."""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import resample_poly

from config import G_TO_MS2, SAMPLE_RATE_HZ, WINDOW_SAMPLES
from schema import validate_window_frame

RAW_AXES = ["ax", "ay", "az", "gx", "gy", "gz"]


def to_g(a: np.ndarray, unit: str) -> np.ndarray:
    unit = unit.lower()
    if unit in ("g", "g0", "gravity"):
        return a
    if unit in ("m/s^2", "m/s2", "ms2", "mps2"):
        return a / G_TO_MS2
    raise ValueError(f"unknown accel unit {unit!r}")


def to_deg_s(g: np.ndarray, unit: str) -> np.ndarray:
    unit = unit.lower()
    if unit in ("deg/s", "dps", "deg_s", "degps"):
        return g
    if unit in ("rad/s", "rps", "rad_s"):
        return np.rad2deg(g)
    raise ValueError(f"unknown gyro unit {unit!r}")


def resample_to_pipeline_fs(df: pd.DataFrame, src_fs: float) -> pd.DataFrame:
    """Polyphase (anti-aliased) resample of the 6 IMU columns to 50 Hz.

    DAMOTO is logged at 1 kHz; the ESP32/MPU6050 target runs at 50 Hz, so real
    windows have to be decimated with an anti-alias filter — plain slicing
    would alias the impact transient.
    """
    if abs(src_fs - SAMPLE_RATE_HZ) < 1e-6:
        return df.reset_index(drop=True)
    # rational factor up/down
    from math import gcd

    up = SAMPLE_RATE_HZ
    down = int(round(src_fs))
    d = gcd(int(up), down)
    up, down = int(up) // d, down // d
    out = {c: resample_poly(df[c].to_numpy(dtype=float), up, down) for c in RAW_AXES}
    return pd.DataFrame(out)


def slice_windows(
    df: pd.DataFrame,
    label: str,
    *,
    start_window_id: int,
    stride: int | None = None,
    drop_last_partial: bool = True,
) -> pd.DataFrame:
    """Cut a continuous 50 Hz recording into fixed 100-sample windows.

    `stride` defaults to WINDOW_SAMPLES (non-overlapping). Pass a smaller
    stride for overlapping windows on the scarce crash class.
    """
    stride = stride or WINDOW_SAMPLES
    n = len(df)
    frames: list[pd.DataFrame] = []
    wid = start_window_id
    for s in range(0, n - (WINDOW_SAMPLES if drop_last_partial else 1), stride):
        seg = df.iloc[s : s + WINDOW_SAMPLES]
        if len(seg) < WINDOW_SAMPLES:
            break
        w = seg[RAW_AXES].reset_index(drop=True).copy()
        w["label"] = label
        w["window_id"] = wid
        frames.append(w)
        wid += 1
    if not frames:
        return pd.DataFrame(columns=[*RAW_AXES, "label", "window_id"])
    return pd.concat(frames, ignore_index=True)


def finalize(frames: list[pd.DataFrame]) -> pd.DataFrame:
    """Concatenate per-segment window frames, renumber ids, validate."""
    non_empty = [f for f in frames if len(f)]
    if not non_empty:
        raise ValueError("no windows produced — check event annotations / paths")
    df = pd.concat(non_empty, ignore_index=True)
    # renumber window_id to a dense 0..K-1 range, preserving grouping
    remap = {old: new for new, old in enumerate(df["window_id"].drop_duplicates())}
    df["window_id"] = df["window_id"].map(remap)
    return validate_window_frame(df)
