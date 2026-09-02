"""Real / controlled-test data adapters.

Every loader here exists to turn an external dataset into the one canonical
window schema `{ax, ay, az, gx, gy, gz, label, window_id}` (see `config.py`
and `03_RULES.md` §3) so `features.py` and `train_model.py` run unchanged.

A loader must NOT reshape the pipeline to fit its source data.
"""
