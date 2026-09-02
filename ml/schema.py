"""Validation helpers for the canonical window-frame schema.

Any loader — `generate_synthetic_data.py` or a real-data adapter under
`loaders/` — should pass its output through `validate_window_frame()` before
writing a CSV, so a shape mismatch fails loudly at the loader instead of
silently downstream in `features.py`.
"""

from __future__ import annotations

import pandas as pd

from config import LABELS, OPTIONAL_COLUMNS, SCHEMA_COLUMNS, WINDOW_SAMPLES


class SchemaError(ValueError):
    """Raised when a window frame does not match the canonical schema."""


def validate_window_frame(df: pd.DataFrame, *, allow_unlabeled: bool = False) -> pd.DataFrame:
    """Check `df` against the `{ax,ay,az,gx,gy,gz,label,window_id}` contract.

    Verifies column names, that every window_id has exactly WINDOW_SAMPLES
    rows, and that each window carries a single known label. Returns `df`
    unchanged (sorted by window_id) so it can be used inline.
    """
    missing = [c for c in SCHEMA_COLUMNS if c not in df.columns]
    if missing:
        raise SchemaError(f"missing required columns: {missing}")

    allowed = set(SCHEMA_COLUMNS) | set(OPTIONAL_COLUMNS)
    extra = [c for c in df.columns if c not in allowed]
    if extra:
        raise SchemaError(
            f"unexpected columns (schema is {SCHEMA_COLUMNS} "
            f"+ optional {OPTIONAL_COLUMNS}): {extra}"
        )

    if "group" in df.columns:
        mixed_g = df.groupby("window_id")["group"].nunique()
        if len(mixed_g[mixed_g > 1]):
            raise SchemaError("some window_id spans more than one 'group' value")

    counts = df.groupby("window_id").size()
    bad = counts[counts != WINDOW_SAMPLES]
    if len(bad):
        raise SchemaError(
            f"{len(bad)} window(s) do not have exactly {WINDOW_SAMPLES} rows "
            f"(e.g. window {bad.index[0]} has {int(bad.iloc[0])})"
        )

    per_window_labels = df.groupby("window_id")["label"].nunique()
    mixed = per_window_labels[per_window_labels > 1]
    if len(mixed):
        raise SchemaError(f"{len(mixed)} window(s) contain more than one label")

    if not allow_unlabeled:
        unknown = sorted(set(df["label"].unique()) - set(LABELS))
        if unknown:
            raise SchemaError(f"unknown label(s) not in config.LABELS: {unknown}")

    return df.sort_values(["window_id"]).reset_index(drop=True)


def n_windows(df: pd.DataFrame) -> int:
    return int(df["window_id"].nunique())
