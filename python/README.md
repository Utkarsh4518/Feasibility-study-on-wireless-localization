# Python evaluation (from MATLAB results)

Evaluation can be rerun in Python using data exported by the MATLAB pipeline. No MATLAB or Simulink is required for this step.

**Prerequisites:** Run the full pipeline in MATLAB at least once with `cfg.save_evaluation_results = true`, so that `results/<timestamp>/evaluation_timeseries.csv` exists.

**Setup:**

```bash
pip install -r requirements.txt
```

**Usage:**

```bash
# Use latest results folder
python evaluate_from_matlab_results.py

# Use a specific folder
python evaluate_from_matlab_results.py ../results/20250209_143022

# Save figures and metrics_python.csv into that folder
python evaluate_from_matlab_results.py ../results/20250209_143022 --save

# Only print recomputed stats (no plots)
python evaluate_from_matlab_results.py --no-plot
```

The script loads `evaluation_timeseries.csv`, recomputes mean/median/max/std per method, and plots trajectory and error histograms. Simulation and estimation run in MATLAB/Simulink; only evaluation data is exported via CSV.
