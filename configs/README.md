# Configuration

All experiment parameters live in **one config struct**, `localization_config()`. Change experiments by editing that file or by loading a saved `.mat`. `validate_config` rejects malformed configs early (`localization:config` errors). The same field names are used by `python/locref.py`, and every report writes `cfg.json`, so a run can be reloaded in Python.

---

## Fields

| Section | Fields | Description |
|---|---|---|
| **Simulation** | `modelName`, `simulinkDir` | Simulink model and folder |
| | `random_seed` | Seed (e.g. 42); `[]` = unseeded. Drives `simulate_scenario` exactly; for Simulink see `check_reproducibility` |
| | `save_evaluation_results` | Write `results/<timestamp>/` after each run |
| **Anchors** | `anchor_layout`, `anchor_pos` | Kx2 positions [m]. Default `'model'` = the model's `(0,0), (0,5), (5,0)`. Other layouts: `anchor_layouts()`. A Simulink run **re-reads the anchors from the model** (`sync_anchors_with_model`) and warns if `anchor_pos` differs |
| **Signals** | `enable_rss`, `enable_aoa`, `enable_rtt` | Turn modalities on/off |
| | `use_ble`, `use_ble_aoa` | Include BLE links in RSS/RTT; BLE AoA (off: Simulink only logs WiFi AoA) |
| | `rss_names`, `aoa_names`, `rtt_names`, `rx_signal_name` | Logged signal names in the Simulink model |
| **Channel** | `channel.wifi`, `channel.ble` | Per technology: `Ptx_dBm`, `PL0_dB`, `n`, `d0_m` (log‑distance path loss) and noise stds `rss_std_dB`, `aoa_std_deg`, `rtt_std_s`. Defaults are copied from the Simulink charts (WiFi n = 2.2, BLE n = 3.0) |
| | `noise_scale.rss/.aoa/.rtt` | Multipliers on those stds (1 = nominal); what sweeps vary |
| **Trajectory** | `trajectory.waypoints`, `.speed_mps`, `.dt` | Path for the pure‑MATLAB simulator (Simulink uses its own agent path) |
| **Smoothing** | `smooth_win`, `smooth_causal` | Moving‑average window; trailing window = online‑usable |
| **Kalman** | `kf_input` | `'raw'` (default) or `'smoothed'` RSS position fed to the filter |
| | `kf_sigma_a`, `kf_R_floor_m2`, `kf_R_fixed_m2`, `kf_chi2_gate`, `kf_max_rejects`, `kf_P0_diag`, `kf_dt_default` | Process noise, measurement noise floor / fallback, gate, re‑init rule, initial covariance |
| **EKF** | `ekf_sigma_a`, `ekf_gate`, `ekf_P0_diag` | Joint range + bearing filter |
| **Fusion** | `fusion_method` | `'inverse_cov'` (default) or `'fixed'` |
| | `fusion_weight_kf` | Weight on RSS‑KF for `'fixed'` (rest on AoA) |
| **Evaluation** | `target_error_m` | Accuracy target used in plots and metrics |
| **Physical** | `speed_of_light` | [m/s] |

Removed since the earlier version: `anchor_x`, `anchor_y` (use `anchor_pos`), `noise_sigma_rss_dB`, `noise_aoa_std_deg`, `noise_rtt_std_s`, `path_loss_*` (now under `channel`), `kf_measurement_var_floor` (→ `kf_R_floor_m2`), `kf_fusion_alpha` (unused).

---

## Rerun by changing only the config

```matlab
cfg = localization_config();
cfg.enable_rtt = false;
cfg.noise_scale.aoa = 2;                 % AoA twice as noisy
cfg = set_anchor_layout(cfg, 'four_corners');   % simulator only
run_simulated_experiment(cfg);
```

Save and reload (nested fields are merged with the defaults, so older `.mat` files stay valid):

```matlab
save_config(cfg, 'configs/exp_no_rtt.mat');
run_experiment(load_config('configs/exp_no_rtt.mat'));
```

Sweeps vary one field by its dotted path: `run_sweep(cfg, 'noise_scale.rtt', [1 4 16], 20)`; `set_cfg_param` errors on a typo instead of silently sweeping nothing.

---

## Files

- `localization_config.m` – the full config (single source of truth)
- `validate_config.m` – checks shapes, ranges, enums
- `anchor_layouts.m`, `set_anchor_layout.m` – named layouts (`model`, `triangle`, `four_corners`, `collinear`)
- `sync_anchors_with_model.m` – reads the anchor `Constant` blocks from the loaded model
- `set_cfg_param.m` – set a nested field from a dotted path
- `load_config.m`, `save_config.m` – `.mat` persistence (recursive merge with defaults on load)
