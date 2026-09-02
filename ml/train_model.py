"""Train + evaluate the Random Forest crash classifier.

ADR-3 (`02_ARCHITECTURE.md`): Random Forest before any neural network — small,
fast, interpretable, portable to an MCU via micromlgen/emlearn once validated.

`03_RULES.md` §3 (non-negotiable reporting rule): every evaluation reports
aggregate accuracy **and** the crash-class false-negative / false-positive
rates. This script refuses to finish without printing all three:

  missed-crash rate     = FN_crash / (all real crash windows)      = 1 - recall
  crash false-alarm rate = FP_crash / (all real non-crash windows) = 1 - specificity
  crash false-discovery  = FP_crash / (all windows predicted crash) = 1 - precision

Usage:
    python train_model.py                       # trains on synthetic data
    python train_model.py --data path/to/windows.csv --provenance real \\
        --provenance-note "DAMOTO falls + SisFall negatives, loaded 2026-09"

The model + a metadata sidecar (feature list, class order, data provenance,
metrics) are written to models/.
"""

from __future__ import annotations

import argparse
import json
import platform
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
)
from sklearn.model_selection import StratifiedGroupKFold, StratifiedKFold

from config import CRASH_LABEL, LABELS, RANDOM_SEED
from features import build_feature_frame

HERE = Path(__file__).parent
DEFAULT_DATA = HERE / "data" / "synthetic" / "windows.csv"
MODEL_DIR = HERE / "models"


def crash_error_rates(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
    """The three numbers `03_RULES.md` §3 requires, plus their raw counts."""
    true_crash = y_true == CRASH_LABEL
    pred_crash = y_pred == CRASH_LABEL

    tp = int(np.sum(true_crash & pred_crash))
    fn = int(np.sum(true_crash & ~pred_crash))
    fp = int(np.sum(~true_crash & pred_crash))
    tn = int(np.sum(~true_crash & ~pred_crash))

    n_crash = tp + fn
    n_noncrash = fp + tn
    n_pred_crash = tp + fp

    return {
        "crash_windows": n_crash,
        "noncrash_windows": n_noncrash,
        "tp": tp, "fn": fn, "fp": fp, "tn": tn,
        "missed_crash_rate": (fn / n_crash) if n_crash else float("nan"),
        "crash_false_alarm_rate": (fp / n_noncrash) if n_noncrash else float("nan"),
        "crash_false_discovery_rate": (fp / n_pred_crash) if n_pred_crash else float("nan"),
        "crash_recall": (tp / n_crash) if n_crash else float("nan"),
        "crash_precision": (tp / n_pred_crash) if n_pred_crash else float("nan"),
    }


def _print_block(title: str) -> None:
    print("\n" + "=" * 70 + f"\n{title}\n" + "=" * 70)


def evaluate(y_true: pd.Series, y_pred: np.ndarray, header: str) -> dict:
    yt = np.asarray(y_true)
    _print_block(header)
    acc = accuracy_score(yt, y_pred)
    bal = balanced_accuracy_score(yt, y_pred)
    print(f"accuracy           : {acc:.4f}")
    print(f"balanced accuracy  : {bal:.4f}")
    print("\nper-class report:")
    print(classification_report(yt, y_pred, labels=list(LABELS), zero_division=0))
    print("confusion matrix (rows = true, cols = pred), label order:")
    print("  " + ", ".join(LABELS))
    print(confusion_matrix(yt, y_pred, labels=list(LABELS)))

    rates = crash_error_rates(yt, y_pred)
    _print_block(f"CRASH-CLASS ERROR RATES - {header}")
    print(f"real crash windows           : {rates['crash_windows']}")
    print(f"real non-crash windows       : {rates['noncrash_windows']}")
    print(f"missed-crash rate  (FN/crash): {rates['missed_crash_rate']:.4f}   "
          f"[{rates['fn']} missed]")
    print(f"false-alarm rate (FP/noncrash): {rates['crash_false_alarm_rate']:.4f}   "
          f"[{rates['fp']} false alarms]")
    print(f"false-discovery  (FP/pred crash): {rates['crash_false_discovery_rate']:.4f}")
    return {"accuracy": acc, "balanced_accuracy": bal, **rates}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", type=Path, default=DEFAULT_DATA)
    ap.add_argument("--provenance", choices=["synthetic", "controlled_test", "real"],
                    default="synthetic",
                    help="data provenance, recorded in the model sidecar and "
                         "gates whether accuracy claims are allowed")
    ap.add_argument("--provenance-note", default="",
                    help="free text: source dataset(s), date loaded, label mapping")
    ap.add_argument("--test-size", type=float, default=0.25)
    ap.add_argument("--n-estimators", type=int, default=300)
    ap.add_argument("--max-depth", type=int, default=None)
    ap.add_argument("--cv-folds", type=int, default=5)
    ap.add_argument("--seed", type=int, default=RANDOM_SEED)
    ap.add_argument("--out", type=Path, default=MODEL_DIR / "rf_crash_classifier.pkl")
    args = ap.parse_args()

    if not args.data.exists():
        raise SystemExit(
            f"no data at {args.data}\n"
            "generate synthetic data first:  python generate_synthetic_data.py\n"
            "or point --data at a window-schema CSV from a loader in loaders/."
        )

    import joblib

    raw = pd.read_csv(args.data)
    X, y, wids, groups = build_feature_frame(raw)
    print(f"loaded {len(X)} windows / {X.shape[1]} features from {args.data}")
    print(y.value_counts().to_string())

    grouped = groups is not None and groups.nunique() > 1
    if grouped:
        print(f"\ngroup-aware evaluation: {groups.nunique()} groups "
              f"({sorted(groups.unique())}) — whole groups are held out so "
              f"correlated overlapping windows never straddle the split.")
    elif args.provenance != "synthetic":
        print("\nWARNING: non-synthetic data with no 'group' column — overlapping "
              "windows from one event may leak across the split and flatter the "
              "metrics. Have the loader emit a 'group' column.")

    def _rf() -> RandomForestClassifier:
        return RandomForestClassifier(
            n_estimators=args.n_estimators, max_depth=args.max_depth,
            class_weight="balanced", random_state=args.seed, n_jobs=-1,
        )

    # --- choose the split -------------------------------------------
    if grouped:
        groups_per_class = (
            pd.DataFrame({"y": y.values, "g": groups.values})
            .groupby("y")["g"].nunique()
        )
        n_splits = max(2, min(args.cv_folds, int(groups_per_class.min())))
        splitter = StratifiedGroupKFold(n_splits=n_splits)
        folds = list(splitter.split(X, y, groups))
        print(f"groups per class: {groups_per_class.to_dict()}  ->  "
              f"{n_splits}-fold grouped CV")
    else:
        n_splits = args.cv_folds
        splitter = StratifiedKFold(n_splits=n_splits, shuffle=True,
                                   random_state=args.seed)
        folds = list(splitter.split(X, y))

    # --- out-of-fold predictions: every window scored once by a model
    #     that never saw its group. This IS the held-out evaluation for a
    #     dataset this small -- one honest confusion matrix over everything.
    oof = pd.Series(index=X.index, dtype=object)
    cv_missed, cv_fa = [], []
    for tr_i, te_i in folds:
        m = _rf().fit(X.iloc[tr_i], y.iloc[tr_i])
        pred = m.predict(X.iloc[te_i])
        oof.iloc[te_i] = pred
        r = crash_error_rates(np.asarray(y.iloc[te_i]), pred)
        cv_missed.append(r["missed_crash_rate"])
        cv_fa.append(r["crash_false_alarm_rate"])

    kind = "grouped " if grouped else ""
    holdout = evaluate(
        y, oof.to_numpy(),
        f"OUT-OF-FOLD ({len(X)} windows, {n_splits}-fold {kind}CV)",
    )
    _print_block(f"PER-FOLD crash error rates ({n_splits}-fold {kind}CV)")
    print(f"missed-crash rate  : mean {np.nanmean(cv_missed):.4f}  "
          f"per fold: {[round(v, 3) for v in cv_missed]}")
    print(f"false-alarm rate   : mean {np.nanmean(cv_fa):.4f}  "
          f"per fold: {[round(v, 3) for v in cv_fa]}")

    clf = _rf().fit(X, y)  # for feature importances + the saved artifact

    # --- feature importances --------------------------------------
    _print_block("TOP 15 FEATURE IMPORTANCES")
    imp = pd.Series(clf.feature_importances_, index=X.columns).sort_values(ascending=False)
    print(imp.head(15).to_string())

    # --- save the all-data model + sidecar ----------------------
    args.out.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(clf, args.out)

    sidecar = args.out.with_suffix(".meta.json")
    meta = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "python": platform.python_version(),
        "model": "RandomForestClassifier",
        "params": clf.get_params(),
        "class_order": list(LABELS),
        "feature_names": list(X.columns),
        "n_windows": int(len(X)),
        "class_counts": {k: int(v) for k, v in y.value_counts().items()},
        "data_path": str(args.data),
        "data_provenance": args.provenance,
        "provenance_note": args.provenance_note,
        "evaluation": "out-of-fold, group-aware" if grouped else "out-of-fold, stratified",
        "n_cv_folds": n_splits,
        "oof_metrics": {k: (None if isinstance(v, float) and np.isnan(v) else v)
                        for k, v in holdout.items()},
        "cv_missed_crash_rate_per_fold": [None if np.isnan(v) else float(v) for v in cv_missed],
        "cv_false_alarm_rate_per_fold": [None if np.isnan(v) else float(v) for v in cv_fa],
    }
    sidecar.write_text(json.dumps(meta, indent=2, default=str))
    print(f"\nsaved model  -> {args.out}")
    print(f"saved sidecar -> {sidecar}")

    if args.provenance == "synthetic":
        _print_block("PROVENANCE WARNING")
        print(
            "This model was trained on SYNTHETIC data. Per 01_REQUIREMENTS.md 4.3\n"
            "[LOCKED] and 03_RULES.md 1: do NOT describe it as field-validated,\n"
            "production-accuracy, or similar anywhere (docs, UI copy, pitch).\n"
            "The four classes are separated by construction; this run validates\n"
            "pipeline mechanics only. Phase 1 exit needs non-synthetic data."
        )


if __name__ == "__main__":
    main()
