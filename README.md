# Indoor Wireless Localization (Simulation)

Feasibility study: can a moving device be located indoors to within 50 cm using only the Wi-Fi and BLE radios it already has, with no extra hardware such as UWB anchors or dedicated receivers? The study uses received signal strength (RSS), round-trip time (RTT) and angle of arrival (AoA) to three fixed anchors.

Author: Utkarsh Maurya (TUHH)

**Everything here is simulation.** There is no hardware, no measured radio data and no calibration. Real-world accuracy would need separate validation.

## Results

Monte Carlo over 100 noise realisations with the default configuration (the three anchors of the Simulink model, a 0.5 m/s path, nominal noise). Error is the Euclidean position error in metres.

| Method | Mean [m] | 95% CI | Median | P90 | RMSE | Within 0.5 m |
|---|---|---|---|---|---|---|
| RSS (raw) | 0.364 | 0.005 | 0.309 | 0.662 | 0.446 | 78.6% |
| RSS smoothed | 0.262 | 0.005 | 0.249 | 0.406 | 0.288 | 96.3% |
| RSS + Kalman | 0.197 | 0.004 | 0.175 | 0.350 | 0.234 | 97.6% |
| AoA | 0.134 | 0.002 | 0.118 | 0.246 | 0.158 | 99.9% |
| RTT | 0.166 | 0.002 | 0.151 | 0.295 | 0.191 | 99.5% |
| Fusion (inverse covariance) | 0.080 | 0.001 | 0.074 | 0.137 | 0.090 | 100% |
| **EKF (raw ranges and bearings)** | **0.061** | 0.001 | 0.056 | 0.108 | 0.071 | **100%** |

The table comes from the Python reference implementation (`python/locref.py`). The MATLAB code run in GNU Octave gives the same numbers within the confidence intervals (EKF 0.062, fusion 0.079, RSS + Kalman 0.196). The two use different random generators, so they agree statistically, not sample for sample.

What the results show:

- With the model's noise (RTT 1 ns for Wi-Fi and 5 ns for BLE, AoA 2 and 5 degrees, RSS 1.5 dB), the single-snapshot Cramér-Rao bound is about 0.06 to 0.15 m everywhere inside the anchor triangle, so the 0.5 m target is met with a wide margin.
- Sensitivity (mean error, 30 runs): AoA noise x4 gives 0.56 m for AoA alone, 0.13 m for fusion and 0.09 m for the EKF. RTT noise x16 gives 2.3 m for RTT alone, 0.10 m for fusion and 0.21 m for the EKF, which depends on its noise model being right.
- Anchor layout matters. Nearly collinear anchors raise the RTT-only error from 0.16 m to 1.1 m and the fusion error from 0.08 m to 0.38 m. Four corner anchors improve every method.
- The model's RTT noise is optimistic. 1 to 5 ns is 0.15 to 0.75 m one way, while commodity Wi-Fi round-trip ranging is commonly reported at about a metre or worse. Treat `noise_scale.rtt` of 8 to 16 as the pessimistic case.

## Problems found in the original code

| Problem | Effect | Fix |
|---|---|---|
| The config listed anchors (1,3), (5,7), (10,11), but the Simulink model's `Constant` blocks hold (0,0), (0,5), (5,0) | AoA and RTT positioning used the wrong anchors, giving errors of 3 to 10 m in simulation | Defaults match the model, and `run_experiment` reads the anchors from the model and warns on a mismatch (`sync_anchors_with_model`) |
| The Kalman measurement noise was computed from `true - estimate` | Ground truth leaked into the filter, so accuracy was optimistic | Noise comes from the estimator's own covariance or a config value; `kalman_filter_cv` takes no truth input |
| Fusion used fixed weights 0.7/0.3, produced NaN whenever AoA was missing, and never used RTT | 0.146 m versus 0.080 m with inverse-covariance fusion | Per-step inverse-covariance fusion, plus a joint EKF |
| The Kalman filter was fed already smoothed positions | Extra lag, worse than smoothing alone | The filter takes raw positions (`cfg.kf_input`): 0.198 m versus 0.298 m |
| The Cramér-Rao bound used the wrong constant and divided by d squared instead of d to the fourth | Not the Fisher information of the log-distance model | Rewritten and unit-tested against closed-form cases |
| Channel parameters in the config (n = 2.7) differed from the model (Wi-Fi n = 2.2, BLE n = 3.0), and several noise fields were unused | The config described a channel the simulation did not use | `cfg.channel.wifi` and `cfg.channel.ble` hold the model's values |
| `est_x/est_y` from Simulink was labelled "RSS" | It is the `fminsearch` minimiser of an RSS + AoA + RTT objective, so fusing it again with AoA/RTT double counts | Labelled accordingly, with a warning; the MATLAB simulator uses an independent RSS-only estimate |

## How it works

```
Simulink model ---> extract_simulink_measurements ---+
simulate_scenario (same channel in MATLAB,           |
   any anchor layout, own seeded RandStream) --------+--> meas --> analyze_run --> res --> report_run
```

`meas` holds the truth and, per link, the RSS, AoA and RTT values with the anchor and technology of each link. Everything after it is identical for Simulink and simulated data. `run_experiment` saves `meas.mat`, and `reanalyze_run` repeats the analysis without Simulink.

| Method | What it does |
|---|---|
| RSS | Inverts the log-distance path loss per technology to get ranges, then solves position by weighted Levenberg-Marquardt and returns a covariance. |
| Smoothing | Trailing moving average of the RSS position (baseline). |
| Kalman | Constant-velocity filter on the RSS position, using the estimator's covariance as measurement noise. Gated, and re-initialised after repeated rejections. |
| AoA | Bearings become lines; weighted least squares with weights 1/(d sigma)^2. |
| RTT | Round-trip time gives ranges (c t / 2); nonlinear weighted least squares over the six Wi-Fi and BLE links. |
| Fusion | Minimum-variance combination of the per-method estimates, skipping any missing at a step. `fusion_method = 'fixed'` restores the original blend. |
| EKF | Each RTT/RSS range and AoA bearing is a scalar measurement with its own variance and innovation gate. Uses the raw geometry and the motion across steps. |
| Error bound | Single-snapshot Cramér-Rao bound from the Fisher information of all enabled links. Static estimators cannot beat it on average; the EKF can because it also uses motion. |

The estimator covariances are statistically consistent: the mean normalised estimation error squared (ideal 2 for a 2-D position) is 1.9 to 2.3 for RSS, AoA, RTT, fusion and the EKF, and 1.2 for the RSS Kalman filter, which is slightly conservative. Machine learning is not part of the pipeline (`ml/` is a placeholder).

## How to run

Requirements: MATLAB R2021a or later (the model was saved in R2023a). Simulink is needed only for `run_experiment`. No other toolboxes.

| Goal | Command, from the repo root |
|---|---|
| Full pipeline with the Simulink model | `run_experiment` |
| Same analysis without Simulink, any anchor layout | `run_simulated_experiment` |
| Many noise realisations with CI, CDF and box plot | `run_monte_carlo(localization_config(), 100, 'OutDir', 'results/mc')` |
| Sensitivity sweep | `run_sweep(cfg, 'noise_scale.aoa', [0.5 1 2 4], 20, 'OutDir', 'results/sweeps')` |
| Anchor layout comparison | `run_sweep(cfg, 'anchor_layout', {'model','triangle','four_corners','collinear'}, 20)` |
| Re-analyse a saved run | `reanalyze_run('results/<folder>', cfg)` |
| Does `rng()` make the Simulink noise repeatable? | `check_reproducibility` |
| Unit tests | `runtests('tests')` |

Experiments are changed through `configs/localization_config.m` only (see `configs/README.md`). `run_simulated_experiment` and `run_monte_carlo` use their own `RandStream` seeded from `cfg.random_seed`, so they are exactly reproducible. Whether `rng()` also seeds the Simulink noise depends on the MATLAB release.

Each run writes `results/<timestamp>/` with `metrics.csv`, `evaluation_timeseries.csv`, `cfg.json`, `meas.mat` and figures (see `docs/RESULTS_FORMAT.md`).

Figures: a trajectory panel per method coloured by error, the error CDF with the 0.5 m target, error over time against the lower bound, and an accuracy map of the anchor layout. Monte Carlo adds a CDF and a box plot; sweeps plot mean error with a 95% CI against the swept parameter.

### Without MATLAB

The Python tools need only `pip install -r python/requirements.txt`:

```bash
python python/dashboard.py --demo --offline    # builds results/python_demo/dashboard.html
python -m pytest python/tests -q
```

`python/dashboard.py <results folder>` builds an interactive report from any MATLAB results folder.

## Limitations

- Simulation only: no hardware, no measured data. Channel parameters come from the Simulink charts, not from measurements. No multipath, non-line-of-sight, antenna patterns or clock drift.
- The MATLAB simulator drives a fixed triangular path inside the anchor hull at 0.5 m/s. The Simulink agent path is the model's own and was not changed.
- Test status: the numeric core of the MATLAB code was executed in GNU Octave (36 test assertions pass, and the 100-run Monte Carlo matches the Python results). Plotting, report writing and the Simulink path have not been executed, so run `runtests('tests')` in MATLAB before relying on them.
- The Simulink `est_x/est_y` already contains AoA and RTT information, so fusion results on Simulink data are optimistic. Use the simulated experiment for a fair comparison.

## Project layout

- `run_experiment.m`, `run_simulated_experiment.m`, `run_monte_carlo.m`, `run_sweep.m`, `reanalyze_run.m`, `check_reproducibility.m`: entry points
- `analyze_run.m`, `report_run.m`: analysis and reporting
- `configs/`: config, validation, anchor layouts, anchor sync with the model
- `signal_models/`: scenario simulator, trajectory, link conversions, Simulink extraction
- `estimators/`: range and bearing solvers
- `filters/`: smoothing, Kalman, EKF, fusion
- `evaluation/`: statistics, error bound, plots, report writer
- `tests/`: `matlab.unittest` suite
- `python/`: reference implementation, dashboard, tests
- `LocalizationRSSandsub/`: the Simulink model
- `docs/`: Simulink model guide, results format
