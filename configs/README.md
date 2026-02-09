# Configuration

All experiment parameters are controlled by a **single configuration structure**. Rerun experiments by changing only the config (edit `localization_config.m` or load a saved `.mat` file).

---

## Config structure (localization_config.m)

| Section | Fields | Description |
|--------|--------|-------------|
| **Simulation** | `modelName`, `simulinkDir` | Simulink model and folder |
| | `random_seed` | Fixed seed for RNG (e.g. 42); [] = no fix. Ensures reproducible runs. |
| | `save_evaluation_results` | If true, run_evaluation_report saves to results/&lt;timestamp&gt;/ after each run. |
| **Anchor geometry** | `anchor_pos`, `anchor_x`, `anchor_y` | Anchor positions [m]; must match Simulink |
| **Signal selection** | `enable_rss`, `enable_aoa`, `enable_rtt` | Turn RSS / AoA / RTT on or off |
| | `rss_names`, `aoa_names`, `rtt_names`, `rx_signal_name` | Log names in Simulink `logsout` |
| **Noise statistics** | `noise_sigma_rss_dB`, `noise_aoa_std_deg`, `noise_rtt_std_s` | RSS [dB], AoA [deg], RTT [s] std |
| **Path loss** | `path_loss_tx_dBm`, `path_loss_ref_dB`, `path_loss_exponent`, `path_loss_ref_dist_m` | Channel model for signal_models and CRLB |
| **Filter parameters** | `smooth_win` | Moving-average window for RSS |
| | `kf_dt_default`, `kf_sigma_a`, `kf_measurement_var_floor`, `kf_P0_diag`, `kf_chi2_gate`, `kf_fusion_alpha` | Kalman filter |
| **Fusion** | `fusion_weight_kf` | Weight on RSS-KF when fusing with AoA (0–1) |
| **Physical** | `speed_of_light` | [m/s] for RTT → distance |

---

## Rerun by changing only config

### Option 1: Edit and run

1. Edit `configs/localization_config.m` (e.g. set `enable_rtt = false`, or change `noise_aoa_std_deg`).
2. From repo root: `run_experiment()` (uses `localization_config()`).

### Option 2: Save and load .mat

1. Create a config (e.g. modify default and save):
   ```matlab
   cfg = localization_config();
   cfg.enable_rtt = false;
   cfg.noise_aoa_std_deg = 5;
   save_config(cfg, 'configs/exp_aoa_only.mat');
   ```
2. Rerun with that config:
   ```matlab
   run_experiment(load_config('configs/exp_aoa_only.mat'));
   ```

`load_config(filepath)` merges the loaded struct with default values from `localization_config()`, so older .mat files remain valid when new fields are added.

---

## Files

- **localization_config.m** – Returns the full config struct (single source of truth).
- **load_config.m** – Load config from .mat (`cfg` or `config` variable); optional merge with defaults.
- **save_config.m** – Save config to .mat for reproducibility.
