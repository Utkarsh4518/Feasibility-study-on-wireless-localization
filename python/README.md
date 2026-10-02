# Python tools

No MATLAB or Simulink is needed for anything in this folder.

```bash
pip install -r requirements.txt
```

| File | Purpose |
|---|---|
| `locref.py` | Reference implementation of the whole pipeline (scenario simulator, range/AoA estimators with covariances, Kalman, joint EKF, inverse-covariance fusion, Cramér-Rao bound, Monte Carlo, sweeps). Mirrors the MATLAB code; used to verify the algorithms and to produce the numbers in the main README. |
| `dashboard.py` | Interactive Plotly report (`dashboard.html`) from any results folder: Monte Carlo table, error CDF + box plot, per-method path explorer, error over time vs lower bound, accuracy map of the anchor layout, sensitivity sweeps. |
| `evaluate_from_matlab_results.py` | Recompute metrics from `evaluation_timeseries.csv` and draw matplotlib figures (CDF, per-method trajectory panels). |
| `demo_data.py` | Writes a results folder in the MATLAB format using `locref.py`. |
| `tests/test_locref.py` | 19 pytest tests (estimators, filters, fusion, bound, scenario, pipeline ordering). |

## Usage

```bash
# Try everything without MATLAB: demo data + dashboard
python dashboard.py --demo                     # -> ../results/python_demo/dashboard.html

# On a MATLAB results folder
python dashboard.py ../results/20260101_120000_sim
python evaluate_from_matlab_results.py ../results/20260101_120000_sim --save --html

# Tests
python -m pytest tests -q
```

`dashboard.py` loads plotly.js from a CDN; add `--offline` to embed it (adds ≈ 3.5 MB).

Random numbers differ from MATLAB's (different generators), so `locref.py` agrees with the MATLAB code statistically, not sample-for-sample. File formats: [`../docs/RESULTS_FORMAT.md`](../docs/RESULTS_FORMAT.md).
