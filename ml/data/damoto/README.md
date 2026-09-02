# DAMOTO dataset — download & layout

**Not committed to git** (see repo `.gitignore`). Each person working on the
ML pipeline downloads it locally.

## Where to get it — it is NOT on Mendeley

The data ships as **supplementary ZIP files attached to the Data in Brief
article and its corrigendum** (not a Mendeley/repository dataset).

| File | Size | From | Contains |
|---|---|---|---|
| `mmc1.zip` | 6.4 MB | **Corrigendum** — https://pmc.ncbi.nlm.nih.gov/articles/PMC7303291/ | the 4 **corrected** fall recordings — **use this for falls** |
| `mmc2.zip` | 6 MB | Original article — https://pmc.ncbi.nlm.nih.gov/articles/PMC6660605/ | supplementary data (falls + near-falls, pre-correction) |
| `mmc3.zip` | 1.9 MB | Original article — same page | extreme-manoeuvre / near-fall recordings |

Direct links (NCBI/PMC, US government host):
- `https://pmc.ncbi.nlm.nih.gov/articles/instance/7303291/bin/mmc1.zip`
- `https://pmc.ncbi.nlm.nih.gov/articles/instance/6660605/bin/mmc2.zip`
- `https://pmc.ncbi.nlm.nih.gov/articles/instance/6660605/bin/mmc3.zip`

Also grab `mmc1.docx` (14 KB, original article) — the "transparency document",
which should describe the file format / column order.

### The corrigendum bug (important)

A binary→ASCII conversion bug in the **original** release swapped the
lateral-acceleration channel **`Ay`** with another sensor. The corrigendum's
`mmc1.zip` has the corrected fall data. The near-fall recordings
(`mmc2`/`mmc3`) were **not** re-released, so if you use them, be aware `Ay`
may still be wrong (the roll/yaw/pitch gyro channels are unaffected).

### Other known limits

- Accelerometer range is only **±1.8 g** → a real ground impact saturates.
  The fall signature is tip-over rotation + sustained post-fall orientation,
  not a clean multi-g spike.
- Gyro spec quoted as "100 °/s" — confirm range vs. resolution against the
  real files.
- Only **4 true fall recordings**, each a long ~1 kHz recording with a single
  labelled fall window (ms timestamps in `loaders/damoto.py::FALL_EVENTS_MS`,
  from Table 1 of the paper).

## Layout expected by `loaders/damoto.py`

Unpack so the recording files land somewhere under this directory:

```
ml/data/damoto/
├── README.md            <- the only committed thing here
├── corrigendum/         <- unzip mmc1.zip here (corrected falls)
├── original_mmc2/       <- unzip mmc2.zip here
└── original_mmc3/       <- unzip mmc3.zip here
```

The loader searches `**/*.csv` recursively. If the real files are `.txt` or
use different column names / separators, run `--describe` first and adjust
`DamotoConfig` in `loaders/damoto.py`.

## First run

```bash
cd ml
python -m loaders.damoto --describe     # prints real columns / row counts / scenario guesses
# reconcile DamotoConfig (column_map, units, source_fs_hz, csv_sep) + the
# scenario/label maps with what --describe shows, then:
python -m loaders.damoto                # writes ../ml/data/damoto_windows.csv
```

Then update the provenance table in `ml/README.md` with the confirmed column
order, units, sampling rate, and the file→label counts.
