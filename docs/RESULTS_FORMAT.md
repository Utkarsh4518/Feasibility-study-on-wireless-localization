# Results folders

Every run writes a timestamped folder under `results/` (git‑ignored; archive specific runs deliberately). Names: `results/20260101_120000` (Simulink), `..._sim` (simulated), plus any folder you pass as `'OutDir'`.

## Single run (`run_experiment`, `run_simulated_experiment`)

| File | Content |
|---|---|
| `metrics.csv` | One row per method: `mean_m, median_m, p90_m, max_m, min_m, std_m, rmse_m, frac_under_target, n` |
| `evaluation_timeseries.csv` | One row per step: `index, t, true_x, true_y`, then per method key `<key>_x`, `<key>_y`, and `err_<key>` (instantaneous Euclidean error, m) |
| `cfg.json` | Config snapshot (loadable with `locref.cfg_from_json`) |
| `meas.mat` | `meas` + `cfg`; input of `reanalyze_run` (no Simulink needed) |
| `metrics.mat`, `report_info.mat` | Stats / result struct; timestamp, seed, MATLAB version, git commit |
| `fig_trajectory`, `fig_cdf`, `fig_error_time`, `fig_crlb_map` `.png/.pdf` | Figures (PNG at 300 dpi, vector PDF) |

Method keys: `rss`, `rss_smooth`, `rss_kf`, `aoa`, `rtt`, `fusion`, `ekf`. Methods that are disabled or produced no estimate have empty (NaN) columns and are omitted from `metrics.csv`.

## Monte Carlo (`run_monte_carlo ... 'OutDir'`)

`mc_summary.csv` (mean, 95% CI of the mean, median, P90, max, std, RMSE, fraction under target), `mc_errors.csv` (long format: `run, step, t, method, err_m`), `cfg.json`, `fig_mc_cdf`, `fig_mc_box`.

## Sweeps (`run_sweep ... 'OutDir'`)

`sweep_<param>.csv` with `param, value, value_num, method, mean_err, ci95, median_err, p90_err, rmse_err, frac_under_target`, and `fig_sweep_<param>`.

## From Python

```bash
python python/evaluate_from_matlab_results.py results/<folder> --save    # stats + matplotlib figures
python python/dashboard.py results/<folder>                              # interactive dashboard.html
```

`python/demo_data.py` writes a folder in exactly this format using the Python reference implementation, so the Python tools can be tried without MATLAB.
