"""Smoke tests: the scaffolding contract stays intact.

Run:  cd ml && python -m pytest -q      (or: python tests/test_pipeline.py)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from config import LABELS, SCHEMA_COLUMNS, WINDOW_SAMPLES  # noqa: E402
from features import build_feature_frame  # noqa: E402
from generate_synthetic_data import generate  # noqa: E402
from loaders.base import resample_to_pipeline_fs, slice_windows  # noqa: E402
from schema import SchemaError, validate_window_frame  # noqa: E402


def test_synthetic_matches_schema():
    df = generate(n_per_class=12, seed=0)
    assert list(df.columns) == list(SCHEMA_COLUMNS)
    assert df.groupby("window_id").size().eq(WINDOW_SAMPLES).all()
    assert set(df["label"]) == set(LABELS)
    assert df.groupby("window_id")["label"].nunique().eq(1).all()


def test_validate_rejects_bad_window_length():
    df = generate(n_per_class=2, seed=1)
    broken = df.iloc[:-1]  # last window now short
    try:
        validate_window_frame(broken)
    except SchemaError:
        return
    raise AssertionError("expected SchemaError for a short window")


def test_features_one_row_per_window_no_nans():
    df = generate(n_per_class=15, seed=2)
    X, y, wids, groups = build_feature_frame(df)
    assert len(X) == df["window_id"].nunique() == len(y) == len(wids)
    assert groups is None  # synthetic data carries no 'group' column
    assert not X.isna().any().any()
    assert np.isfinite(X.to_numpy()).all()


def test_recovery_ratio_separates_classes():
    df = generate(n_per_class=80, seed=3)
    X, y, _, _ = build_feature_frame(df)
    med = {lbl: X.loc[y.values == lbl, "g_recovery_ratio"].median() for lbl in LABELS}
    # normal riding: gyro roughly stationary across the window -> ratio ~ 1
    assert 0.7 < med["normal_riding"] < 1.4
    # pothole: first-half spike, second half back to baseline -> ratio < normal
    assert med["pothole_bump"] < med["normal_riding"]
    # crash: second half settled on the ground (gyro ~ 0) -> ratio near zero,
    # clearly below the pothole case
    assert med["crash_impact"] < 0.15
    assert med["crash_impact"] < med["pothole_bump"]
    # harsh brake: disturbance ramps up over the window -> ratio > 1
    assert med["harsh_brake"] > med["normal_riding"]


def test_group_column_roundtrips_through_schema_and_features():
    df = generate(n_per_class=6, seed=5)
    # tag each window with a fake group id
    gmap = {w: f"grp{w % 3}" for w in df["window_id"].unique()}
    df["group"] = df["window_id"].map(gmap)
    validate_window_frame(df)  # must not raise
    X, y, wids, groups = build_feature_frame(df)
    assert groups is not None and len(groups) == len(X)
    assert set(groups) == {"grp0", "grp1", "grp2"}


def test_schema_rejects_group_split_across_window():
    df = generate(n_per_class=2, seed=6)
    df["group"] = "a"
    df.loc[df.index[-1], "group"] = "b"  # one row of the last window differs
    try:
        validate_window_frame(df)
    except SchemaError:
        return
    raise AssertionError("expected SchemaError for a window spanning two groups")


def test_damoto_windows_if_present():
    """Runs only when the real DAMOTO CSVs have been downloaded."""
    from loaders.damoto import DATA_DIR, build_windows

    if not any(DATA_DIR.rglob("*.csv")):
        print("  (skipped: no DAMOTO data under ml/data/damoto/)")
        return
    df = build_windows()
    validate_window_frame(df)
    assert "group" in df.columns
    labels = set(df["label"])
    assert "crash_impact" in labels
    # crash windows must come from >= 2 distinct falls so grouped CV is possible
    crash_groups = df.loc[df["label"] == "crash_impact", "group"].nunique()
    assert crash_groups >= 2


def test_resample_and_window_roundtrip():
    # 4 s of fake 1 kHz data -> 50 Hz -> two clean 100-sample windows
    n = 4000
    raw = pd.DataFrame(
        {c: np.random.default_rng(4).normal(size=n)
         for c in ["ax", "ay", "az", "gx", "gy", "gz"]}
    )
    ds = resample_to_pipeline_fs(raw, src_fs=1000.0)
    assert abs(len(ds) - 200) <= 2
    wins = slice_windows(ds, "normal_riding", start_window_id=0)
    assert wins["window_id"].nunique() >= 1
    validate_window_frame(wins)


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for fn in fns:
        fn()
        print(f"ok  {fn.__name__}")
    print(f"\n{len(fns)} passed")
