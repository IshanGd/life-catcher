"""Feature extraction over `{ax,ay,az,gx,gy,gz,label,window_id}` windows.

Feature families are exactly those named in `01_REQUIREMENTS.md` §4.3:

  - magnitude statistics (accel + gyro magnitude)
  - jerk (derivative of acceleration)
  - signal magnitude area (SMA)
  - FFT dominant frequency / energy
  - g_recovery_ratio  -- gyro magnitude in the first vs. second half of the
    window; the key signal separating a crash (bike stays down, gyro settles)
    from a pothole (transient recovers). See the module for the exact form.

Per-axis means are also included because a sustained post-impact gravity
rotation onto a horizontal axis is one of the strongest crash cues.

`build_feature_frame()` is the single entry point used by `train_model.py`
and, later, by any real-data evaluation.
"""

from __future__ import annotations

import numpy as np
import pandas as pd

from config import SAMPLE_RATE_HZ, WINDOW_SAMPLES
from schema import validate_window_frame

FS = SAMPLE_RATE_HZ
EPS = 1e-9

ACCEL_AXES = ["ax", "ay", "az"]
GYRO_AXES = ["gx", "gy", "gz"]


def _magnitude(a: np.ndarray) -> np.ndarray:
    return np.sqrt(np.sum(a * a, axis=1))


def _stats(x: np.ndarray, prefix: str) -> dict[str, float]:
    return {
        f"{prefix}_mean": float(np.mean(x)),
        f"{prefix}_std": float(np.std(x)),
        f"{prefix}_min": float(np.min(x)),
        f"{prefix}_max": float(np.max(x)),
        f"{prefix}_range": float(np.ptp(x)),
        f"{prefix}_rms": float(np.sqrt(np.mean(x * x))),
        f"{prefix}_energy": float(np.sum(x * x) / len(x)),
        f"{prefix}_iqr": float(np.subtract(*np.percentile(x, [75, 25]))),
    }


def _dominant_frequency(x: np.ndarray) -> tuple[float, float, float]:
    """Return (dominant_freq_hz, dominant_power, spectral_energy) for a signal.

    DC component removed first so the dominant bin is a real oscillation, not
    the mean.
    """
    xd = x - np.mean(x)
    spec = np.abs(np.fft.rfft(xd)) ** 2
    freqs = np.fft.rfftfreq(len(xd), d=1.0 / FS)
    if len(spec) <= 1:
        return 0.0, 0.0, 0.0
    k = int(np.argmax(spec[1:]) + 1)
    return float(freqs[k]), float(spec[k]), float(np.sum(spec))


def extract_features(window: pd.DataFrame) -> dict[str, float]:
    """One window (WINDOW_SAMPLES rows) -> flat feature dict."""
    a = window[ACCEL_AXES].to_numpy(dtype=float)
    g = window[GYRO_AXES].to_numpy(dtype=float)
    a_mag = _magnitude(a)
    g_mag = _magnitude(g)

    feats: dict[str, float] = {}

    # --- magnitude statistics -------------------------------------------
    feats.update(_stats(a_mag, "amag"))
    feats.update(_stats(g_mag, "gmag"))

    # --- per-axis mean/std (gravity direction, sustained tilt) ----------
    for name in ACCEL_AXES + GYRO_AXES:
        col = window[name].to_numpy(dtype=float)
        feats[f"{name}_mean"] = float(np.mean(col))
        feats[f"{name}_std"] = float(np.std(col))

    # --- jerk (d/dt of acceleration magnitude) -------------------------
    jerk = np.diff(a_mag) * FS
    feats["jerk_absmean"] = float(np.mean(np.abs(jerk)))
    feats["jerk_absmax"] = float(np.max(np.abs(jerk))) if len(jerk) else 0.0
    feats["jerk_std"] = float(np.std(jerk)) if len(jerk) else 0.0

    # --- signal magnitude area ----------------------------------------
    feats["sma_accel"] = float(np.mean(np.sum(np.abs(a), axis=1)))
    feats["sma_gyro"] = float(np.mean(np.sum(np.abs(g), axis=1)))

    # --- FFT dominant frequency / energy ----------------------------
    a_f, a_p, a_e = _dominant_frequency(a_mag)
    g_f, g_p, g_e = _dominant_frequency(g_mag)
    feats["amag_dom_freq"] = a_f
    feats["amag_dom_power"] = a_p
    feats["amag_spec_energy"] = a_e
    feats["gmag_dom_freq"] = g_f
    feats["gmag_dom_power"] = g_p
    feats["gmag_spec_energy"] = g_e

    # --- recovery ratios: first half vs second half -----------------
    half = WINDOW_SAMPLES // 2
    g_first, g_second = g_mag[:half], g_mag[half:]
    a_first, a_second = a_mag[:half], a_mag[half:]
    # gyro magnitude second-half / first-half. Pothole: transient in the first
    # half, quiet second half -> low ratio but the FIRST-half spike is large.
    # Crash: violent first half AND a settled (near-zero gyro) second half, but
    # combined with a rotated gravity vector. Provide the raw halves too so the
    # model can separate the cases.
    feats["g_recovery_ratio"] = float(np.mean(g_second) / (np.mean(g_first) + EPS))
    feats["a_recovery_ratio"] = float(np.mean(a_second) / (np.mean(a_first) + EPS))
    feats["gmag_first_half_max"] = float(np.max(g_first)) if len(g_first) else 0.0
    feats["gmag_second_half_max"] = float(np.max(g_second)) if len(g_second) else 0.0
    feats["amag_first_half_max"] = float(np.max(a_first)) if len(a_first) else 0.0
    feats["amag_second_half_max"] = float(np.max(a_second)) if len(a_second) else 0.0
    # how far the second-half gravity direction sits from "upright" (-az ~ 1g)
    second = window.iloc[half:]
    feats["az_second_half_mean"] = float(np.mean(second["az"].to_numpy(dtype=float)))
    feats["axy_second_half_absmean"] = float(
        np.mean(np.abs(second[["ax", "ay"]].to_numpy(dtype=float)))
    )

    return feats


def build_feature_frame(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series, pd.Series]:
    """Window-frame -> (X features, y labels, window_ids), one row per window."""
    df = validate_window_frame(df)
    rows: list[dict[str, float]] = []
    labels: list[str] = []
    wids: list[int] = []
    for wid, window in df.groupby("window_id", sort=True):
        rows.append(extract_features(window))
        labels.append(window["label"].iloc[0])
        wids.append(int(wid))
    X = pd.DataFrame(rows)
    return X, pd.Series(labels, name="label"), pd.Series(wids, name="window_id")


FEATURE_NAMES = None  # populated lazily by train_model for the metadata sidecar
