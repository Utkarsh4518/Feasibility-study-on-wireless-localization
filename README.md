# Indoor Wireless Localization (Simulation)

Feasibility study for locating a moving device indoors using only existing radios (Wi‑Fi and BLE)—no extra hardware like dedicated receivers or UWB anchors. The goal is to see whether sub‑50 cm accuracy is achievable in principle with signal strength, round‑trip time, and angle-of-arrival.

---

## Problem

Laboratory and industrial setups need to know where devices are (e.g. on a bench or along a track) for automation and tracking. Many solutions rely on extra infrastructure: dedicated receivers, UWB base stations, or wired beacons. This project explores what is possible when:

- You **cannot add** new receivers or dedicated localization hardware.
- You **can use** the device’s own Wi‑Fi and BLE links to fixed anchors.
- You care about **accuracy** (target &lt; 50 cm) and **reproducibility** of experiments.

All work here is done in **simulation** (MATLAB/Simulink). No real radios or measurements are used.

---

## Simulation-only disclaimer

**Every result in this repository comes from the MATLAB/Simulink simulation.**

- There is no deployment on hardware and no real-world data.
- Reported accuracy numbers are simulation outputs only.
- Real-world performance would require separate validation (channel, hardware, environment).
- The code and config are set up so runs are reproducible (fixed RNG seed, single config file).

---

## System architecture

High-level flow:

1. **Simulink model** – A moving agent and three fixed anchors. The model simulates Wi‑Fi and BLE links: path loss, RSS (received signal strength), RTT (round‑trip time), and AoA (angle of arrival). It outputs ground-truth position and raw RSS-based position estimates, plus logged RSS, AoA, and RTT signals.
2. **Post-processing (MATLAB)** – Reads the Simulink output and runs:
   - **Filtering:** moving-average smoothing of RSS-derived positions, then a constant-velocity Kalman filter.
   - **Estimators:** position from AoA (weighted least squares) and from RTT (trilateration from distances).
   - **Fusion:** weighted combination of Kalman-filtered RSS and AoA position.
3. **Evaluation:** error metrics (mean, median, max, std) per method, trajectory plots, error histograms, and optional save of reports under `results/<timestamp>/`.

```
[Anchors 1–3]  ──►  [Simulink: channel, RSS/RTT/AoA]  ──►  [Agent: raw position]
                              │
                              ▼
              [MATLAB: smooth → Kalman | AoA WLS | RTT trilateration]
                              │
                              ▼
              [Fusion (RSS+AoA)]  ──►  [Metrics + plots + results/]
```

Config (anchors, noise, filter parameters, fusion weight, random seed) is centralized in `configs/localization_config.m`. Changing only the config is enough to rerun experiments.

---

## Algorithms

| Role | Method | What it does |
|------|--------|----------------|
| **RSS** | Log-distance path loss + moving average | Converts received power to distance; smooths RSS-based position over time. |
| **RTT** | Round-trip time → distance; least-squares trilateration | Converts RTT to range, then solves for position from ranges to anchors. |
| **AoA** | Angle of arrival; weighted least squares | Uses bearing angles from anchors to compute position. |
| **Kalman** | Constant-velocity model on (x, y) | Filters smoothed RSS position; Mahalanobis gating drops bad measurements. |
| **Fusion** | Weighted average | Combines Kalman position and AoA position (weights in config). |
| **ML** | Not used | The `ml/` folder is reserved for an optional learned refinement step; the current pipeline uses only the above. |

RSS and RTT use least-squares position solvers. AoA uses a WLS line-intersection formulation. No neural networks or trained models are in the main pipeline.

---

## Key results (simulation)

Accuracy is reported **per method** (RSS smoothed, RSS Kalman, AoA WLS, RTT trilateration, fusion) as:

- **Mean error** (m)  
- **Median error** (m)  
- **Max error** (m)  
- **Standard deviation** (m)  

These are printed in the MATLAB console and written to `results/<timestamp>/metrics.csv` and `metrics.mat` when evaluation saving is on. Typical runs (default config, fixed seed) give **mean errors in the sub-metre to low metre range** depending on noise and anchor layout; fusion of RSS and AoA generally does better than either alone. Exact numbers depend on config (noise levels, anchors, fusion weight)—run the pipeline once to see the quantified accuracy for your setup.

---

## Limitations

- **Simulation-only.** All results are produced by the MATLAB/Simulink simulation. There is no deployment on real hardware and no use of measured radio data. Reported accuracy is that of the simulated scenario.
- **No real hardware calibration.** Noise levels, path loss parameters, and filter/estimator settings are set in configuration. No calibration step using real devices or collected measurements is implemented.
- **ML not integrated.** Machine learning is not part of the pipeline. The `ml/` folder is reserved for future work; the current system uses only the classical methods listed above.

---

## How to run (3 steps)

1. **Open the project**  
   Clone or open the repo. You need **MATLAB** (R2021a or later; model saved in R2023a) and **Simulink**. No extra toolboxes are required.

2. **Set the working directory**  
   In MATLAB, set the current folder to the repository root (the folder that contains `run_experiment.m`).

3. **Run the pipeline**  
   In the command window:
   ```matlab
   run_experiment
   ```
   This loads the config, runs the Simulink model, runs filtering and estimation, prints metrics, opens plots, and (if `cfg.save_evaluation_results` is true) writes a timestamped report under `results/`.

To use a saved config (e.g. after changing parameters and saving):
```matlab
run_experiment(load_config('configs/my_experiment.mat'))
```

Reproducibility: the default config sets a fixed random seed (`cfg.random_seed = 42`). Same config and seed produce the same simulation and metrics.

---

## Project layout (short)

- **`run_experiment.m`** – Entry point: runs Simulink, then filters, estimators, fusion, and evaluation.
- **`configs/`** – Single config file; all tunables (anchors, noise, filters, seed, save flag) live here.
- **`signal_models/`** – Path loss and AoA simulation (e.g. for RSS and CRLB).
- **`filters/`** – Smoothing and Kalman filter.
- **`estimators/`** – Position from distances (trilateration) and from AoA (WLS).
- **`evaluation/`** – Metrics, trajectory and error plots, and the report that writes to `results/`.
- **`python/`** – Optional: load MATLAB-generated `results/<timestamp>/evaluation_timeseries.csv`, recompute metrics and redraw trajectory/histograms.
- **`LocalizationRSSandsub/`** – Simulink model (`.slx`), agent trajectory data, and tests.

Further detail: `configs/README.md` (config fields and reruns), `docs/SIMULINK_MODEL_GUIDE.md` (Simulink model overview).
