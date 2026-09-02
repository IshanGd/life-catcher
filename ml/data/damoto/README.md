# DAMOTO dataset — download & layout

**Not committed to git** (see repo `.gitignore`). Each person working on the
ML pipeline downloads it locally.

## Where to get it

"Dataset on powered two wheelers fall and critical events detection" —
Boubezoul, Espié, Larnaudie, Bouaziz (2019).

- Paper (open access, Data in Brief 23:103828):
  https://doi.org/10.1016/j.dib.2019.103828
- Data (Mendeley Data): https://doi.org/10.17632/n6pgvs3d24
- Check the paper for the **corrigendum** (Data in Brief 30, 2020) before
  relying on channel order / units.

## Layout expected by `loaders/damoto.py`

Unpack so that the recording files land somewhere under this directory:

```
ml/data/damoto/
├── README.md              <- this file (the only committed thing here)
├── <whatever the archive unpacks to>/
│   ├── ...fall...curve...csv
│   ├── ...brake...csv
│   └── ...normal...csv
```

The loader searches `**/*.csv` recursively and guesses each file's scenario
from its path (`fall`/`chute`, `curve`/`virage`, `slip`, `rond`,
`brake`/`frein`, `normal`/`ride`). If the real filenames don't contain those
hints, edit `DamotoConfig.filename_scenario_hints` and `SCENARIO_TO_LABEL`
in `loaders/damoto.py`.

## First run

```bash
cd ml
python -m loaders.damoto --describe     # prints real columns / row counts / scenario guesses
# adjust DamotoConfig (column_map, units, source_fs_hz, csv_sep) to match, then:
python -m loaders.damoto                # writes ../ml/data/damoto_windows.csv
```

Then update the provenance table in `ml/README.md` with the confirmed
column order, units, sampling rate, and the file→label counts you got.
