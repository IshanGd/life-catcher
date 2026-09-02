"""Shared constants for the crash-detection ML pipeline.

These values are the *contract* between every stage of the pipeline
(synthetic generation, real-data loaders, feature extraction, training) and
they mirror the hardware assumptions in `01_REQUIREMENTS.md` §4.3:

    windowed 6-axis IMU data (accel x/y/z + gyro x/y/z) at 50 Hz,
    2-second windows (100 samples/window)

Do not change SAMPLE_RATE_HZ / WINDOW_SECONDS without a matching change to the
firmware sampling config and a note in `ml/README.md` — the ported model will
only be valid for the window shape it was trained on.
"""

from __future__ import annotations

# --- Window shape (matches ESP32 + MPU6050 target) --------------------------
SAMPLE_RATE_HZ: int = 50
WINDOW_SECONDS: float = 2.0
WINDOW_SAMPLES: int = int(round(SAMPLE_RATE_HZ * WINDOW_SECONDS))  # 100

# --- Label set -------------------------------------------------------------
# Must stay identical to the ML label set in `01_REQUIREMENTS.md` §4.3 and the
# `event_type` values in the BLE contract (`02_ARCHITECTURE.md` §4).
LABELS: tuple[str, ...] = (
    "normal_riding",
    "pothole_bump",
    "harsh_brake",
    "crash_impact",
)

# The one class whose error rates we report separately and care about most
# (see `01_REQUIREMENTS.md` §4.3 and `03_RULES.md` §3).
CRASH_LABEL: str = "crash_impact"

# --- Canonical window-frame schema ---------------------------------------
# Every loader (synthetic or real) must emit a table with exactly these
# columns. `03_RULES.md` §3: real data with a different shape gets an adapter
# that produces THIS schema, not a reshaped pipeline.
SCHEMA_COLUMNS: tuple[str, ...] = (
    "ax", "ay", "az",   # accel, units: g
    "gx", "gy", "gz",   # gyro, units: deg/s
    "label",            # one of LABELS
    "window_id",        # int; 100 consecutive rows share one window_id + label
)

# Optional columns a loader MAY add. `group` names the physical event /
# recording a window came from, so evaluation can hold out whole events
# instead of leaking correlated overlapping windows across the split
# (real-data windows from one fall must not sit in both train and test).
OPTIONAL_COLUMNS: tuple[str, ...] = ("group",)

# --- Units -----------------------------------------------------------------
# The pipeline works in these units end to end. Loaders convert into them.
ACCEL_UNIT: str = "g"        # 1 g = 9.80665 m/s^2
GYRO_UNIT: str = "deg/s"
G_TO_MS2: float = 9.80665

# --- Reproducibility -----------------------------------------------------
RANDOM_SEED: int = 42
