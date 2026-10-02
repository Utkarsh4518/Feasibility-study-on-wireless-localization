# Indoor Wireless Localization (Simulation)

Feasibility study for locating a moving device indoors using only existing radios (Wi‑Fi and BLE), with no extra hardware such as dedicated receivers or UWB anchors. The question: is sub‑50 cm accuracy achievable in principle from signal strength (RSS), round‑trip time (RTT) and angle of arrival (AoA)?

> **Simulation only.** Every number in this repository comes from simulation (MATLAB/Simulink, or the Python reference implementation of the same algorithms). There is no hardware, no measured radio data and no calibration. Real‑world accuracy would need separate validation.

---

## Problem

Laboratory and industrial setups need to know where devices are (on a bench, along a track). Many solutions add infrastructure. This project asks what is possible when you **cannot add** receivers, **can use** the device's own Wi‑Fi and BLE links to three fixed anchors, and care about **accuracy** (target < 50 cm) and **reproducibility**.

---

## Results (simulation)

100‑run Monte Carlo, default config (three anchors of the Simulink model, 0.5 m/s path, nominal noise). Error = Euclidean position error in metres.

| Method | Mean [m] | ±95% CI | Median | P90 | RMSE | ≤ 0.5 m |
|---|---|---|---|---|---|---|
| RSS (raw) | 0.364 | 0.005 | 0.309 | 0.662 | 0.446 | 78.6% |
| RSS smoothed | 0.262 | 0.005 | 0.249 | 0.406 | 0.288 | 96.3% |
| RSS + Kalman | 0.197 | 0.004 | 0.175 | 0.350 | 0.234 | 97.6% |
| AoA WLS | 0.134 | 0.002 | 0.118 | 0.246 | 0.158 | 99.9% |
| RTT trilateration | 0.166 | 0.002 | 0.151 | 0.295 | 0.191 | 99.5% |
| Fusion (inverse‑covariance) | 0.080 | 0.001 | 0.074 | 0.137 | 0.090 | 100% |
| **EKF (joint, raw ranges + bearings)** | **0.061** | 0.001 | 0.056 | 0.108 | 0.071 | **100%** |

These numbers were produced by the Python reference implementation (`python/locref.py`), which mirrors the MATLAB code. MATLAB uses a different random generator, so its numbers agree statistically but not sample‑for‑sample. Reproduce either way:

```bash
python python/dashboard.py --demo          # Python: builds results/python_demo/dashboard.html
```
```matlab
mc = run_monte_carlo(localization_config(), 100, 'OutDir', 'results/mc');   % MATLAB
```

What drives the result:

- **Geometry and noise, not the algorithm, set the floor.** With the model's noise (RTT 1 ns WiFi / 5 ns BLE, AoA 2° / 5°, RSS 1.5 dB) the single‑snapshot Cramér‑Rao bound is ≈ 0.06–0.15 m everywhere inside the anchor triangle, so the 0.5 m target is met with margin.
- **Sensitivity** (mean error, 30 runs): AoA noise ×4 → AoA alone 0.56 m but fusion 0.13 m, EKF 0.09 m. RTT noise ×4 → RTT alone 0.67 m, fusion 0.10 m. RTT noise ×16 → RTT alone 2.3 m, fusion 0.10 m, EKF 0.21 m (the EKF depends on its noise model being right).
- **Anchor layout matters.** Nearly collinear anchors raise RTT‑only error from 0.16 m to 1.1 m and fusion from 0.08 m to 0.38 m; four corner anchors improve every method.
- **The model's RTT noise is optimistic.** 1–5 ns is 0.15–0.75 m one‑way, while commodity Wi‑Fi round‑trip‑time ranging is commonly reported at about a metre or worse. Treat `noise_scale.rtt` of 8–16 as the pessimistic case.

### Corrections to earlier versions of this repository

Reviewing the code against the Simulink model found problems that made the old numbers unreliable:

| Problem | Effect | Fix |
|---|---|---|
| `localization_config.m` listed anchors (1,3), (5,7), (10,11) while the model's `Constant` blocks hold **(0,0), (0,5), (5,0)** | AoA and RTT positioning solved against the wrong anchors: **errors of 3–10 m** (reproduced in simulation) | Default anchors now match the model; `run_experiment` reads them from the model and overrides/warns on mismatch (`sync_anchors_with_model`) |
| Kalman measurement noise `R` was computed from `true − estimate` | Ground truth leaked into the filter; accuracy optimistic | `R` comes from the estimator's own covariance or a config value; `kalman_filter_cv` takes no truth input |
| Fusion used fixed weights 0.7/0.3 and produced NaN whenever AoA was missing | 0.146 m vs 0.080 m with inverse‑covariance fusion; RTT never used | Per‑step inverse‑covariance fusion of RSS‑KF, AoA, RTT; joint EKF added |
| Kalman filter was fed already‑smoothed positions | Extra lag; worse than smoothing alone | Filter takes raw positions (`cfg.kf_input`) → 0.198 m vs 0.298 m |
| CRLB used λ = 10/(n ln 10) and divided by d² | Not the Fisher information of the log‑distance model | `fisher_information` / `compute_crlb_*` rewritten and unit‑tested against hand formulas |
| Channel parameters in the config (n = 2.7, …) differed from the model charts (WiFi n = 2.2, BLE n = 3.0, own noise stds) and several noise fields were unused | Config suggested parameters the simulation did not use | `cfg.channel.wifi/.ble` hold the values from the model |
| `est_x/est_y` from Simulink was labelled "RSS" | It is the `fminsearch` minimiser of an **RSS + AoA + RTT** objective (chart `LocalizationSolver`); fusing it again with AoA/RTT double‑counts | Labelled "Model est. (RSS+AoA+RTT)"; `analyze_run` warns; an independent RSS‑only estimator is used in the MATLAB simulator |

---

## System architecture

```
 Simulink model ─────────────► extract_simulink_measurements ─┐
 (3 anchors, WiFi+BLE channel,                                │      meas
  moving agent)                                               ├────► struct ──► analyze_run ──► res ──► report_run
 simulate_scenario  (same channel in pure MATLAB, ────────────┘                      │                 (metrics, figures,
  any anchor layout, own seeded RandStream)                                          │                  CSV, cfg.json)
                                                                                     ▼
                              RSS→ranges→LS → smooth → Kalman        ─┐
                              AoA bearings → weighted LS             ─┼─► inverse‑covariance fusion
                              RTT ranges → nonlinear weighted LS     ─┘
                              raw ranges + bearings → EKF
```

`meas` is the common data format (truth, per‑link RSS/AoA/RTT values, anchor index and technology of each link), so everything downstream is identical for Simulink and simulated data. `run_experiment` saves `meas.mat`; `reanalyze_run` repeats the analysis without Simulink.

## Algorithms

| Method | What it does |
|---|---|
| **RSS** | Inverts the log‑distance path loss per technology to get ranges (std ∝ range), solves position by weighted Levenberg–Marquardt, returns a covariance. |
| **Smoothing** | Trailing (causal) moving average of the RSS position (baseline). |
| **Kalman** | Constant‑velocity filter on the RSS position with the estimator's covariance as `R`; Mahalanobis gating; re‑initialises after repeated rejections. |
| **AoA** | Bearings → lines → weighted least squares; weights 1/(d·σθ)² from a first pass. |
| **RTT** | Round‑trip time → ranges (`c·t/2`); nonlinear weighted least squares over the 6 WiFi+BLE links. |
| **Fusion** | Minimum‑variance combination of the per‑method estimates, skipping any that are missing at a step. `fusion_method = 'fixed'` restores the original 0.7/0.3 blend. |
| **EKF** | Every RTT/RSS range and AoA bearing is a scalar measurement with its own variance and innovation gate. Uses geometry directly, and the motion model across steps. |
| **Error bound** | Single‑snapshot Cramér–Rao bound from the Fisher information of all enabled links. Static estimators cannot beat it on average; the EKF can because it also uses motion. |
| **ML** | Not implemented (`ml/` is a placeholder). |

The covariances are statistically consistent: the mean normalised estimation error squared (ideal 2 for a 2‑D position) is 1.9–2.3 for RSS, AoA, RTT, fusion and EKF in the Python reference; the RSS Kalman filter is conservative (1.2).

---

## How to run

You need **MATLAB** (R2021a+; model saved in R2023a); **Simulink** only for `run_experiment`. No toolboxes beyond base MATLAB and Simulink.

| Goal | Command (from the repo root) |
|---|---|
| Full pipeline with the Simulink model | `run_experiment` |
| Same analysis, no Simulink, any anchor layout | `run_simulated_experiment` |
| Many noise realisations, CI, CDF + box plot | `run_monte_carlo(localization_config(), 100, 'OutDir', 'results/mc')` |
| Sensitivity sweep | `run_sweep(cfg, 'noise_scale.aoa', [0.5 1 2 4], 20, 'OutDir', 'results/sweeps')` |
| Anchor layout comparison | `run_sweep(cfg, 'anchor_layout', {'model','triangle','four_corners','collinear'}, 20)` |
| Re‑analyse a saved run | `reanalyze_run('results/<folder>', cfg)` |
| Is the Simulink noise seedable? | `check_reproducibility` |
| Unit tests | `runtests('tests')` |
| Interactive report | `python python/dashboard.py results/<folder>` |

Experiments are changed through `configs/localization_config.m` only (see `configs/README.md`). `run_simulated_experiment` and `run_monte_carlo` use their own `RandStream` seeded from `cfg.random_seed`, so they are exactly reproducible. Whether `rng()` also makes the *Simulink* noise repeatable depends on your MATLAB release; `check_reproducibility` tells you.

Each run writes `results/<timestamp>/`: `metrics.csv`, `evaluation_timeseries.csv`, `cfg.json`, `meas.mat`, `fig_*.png/.pdf` (see `results/README.md`).

### Figures

`trajectory` (one panel per method, coloured by error) · `cdf` (error CDF with the 0.5 m target) · `error_time` (error vs lower bound) · `crlb_map` (achievable accuracy over the room) · Monte Carlo: CDF and box plot · sweeps: mean error ± 95% CI vs parameter.

---

## Limitations

- **Simulation only.** No hardware, no measured data, no calibration. Channel parameters are taken from the Simulink charts, not from measurements.
- **Optimistic noise.** See the RTT note above; also no multipath, NLOS, antenna patterns or clock drift.
- **Trajectory.** The MATLAB simulator drives a fixed triangular path inside the anchor hull at 0.5 m/s; the Simulink agent path is the model's own and was not changed.
- **MATLAB code status.** The MATLAB code parses and lints cleanly (MISS_HIT), and its algorithms are verified by the Python reference (19 tests), but it was written without access to MATLAB, so run `runtests('tests')` first.
- **Simulink est_x/est_y** already contains AoA and RTT information, so fusion results on Simulink data are optimistic; use the simulated experiment for a fair comparison.
- **ML not integrated.**

## Project layout

- `run_experiment.m`, `run_simulated_experiment.m`, `run_monte_carlo.m`, `run_sweep.m`, `reanalyze_run.m`, `check_reproducibility.m` – entry points.
- `analyze_run.m`, `report_run.m` – analysis and reporting.
- `configs/` – config, validation, anchor layouts, anchor sync with the model.
- `signal_models/` – scenario simulator, trajectory, link conversions, Simulink extraction.
- `estimators/` – range and bearing solvers. `filters/` – smoothing, Kalman, EKF, fusion.
- `evaluation/` – statistics, error bound, plots, report writer.
- `tests/` – `matlab.unittest` suite. `python/` – reference implementation, dashboard, tests.
- `LocalizationRSSandsub/` – Simulink model. `legacy/` – superseded scripts, kept for reference. `docs/` – model guide, improvement plan.
