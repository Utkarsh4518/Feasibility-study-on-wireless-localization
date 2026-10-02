# Simulink Model Guide: 5-Minute Overview

**Model:** `Localization_Ependorfv2.slx`  
**Purpose:** Simulate indoor wireless localization: anchors and a moving agent, with RSS, AoA, and RTT signals fed into position estimation (simulation only).

---

## 1. High-level signal flow (top level)

```
  [Anchor 1] ──┬──► [Channel_And_Ranging] ──┬──► [Agent] ──► true_x, true_y (ground truth)
  [Anchor 2] ──┼──►   (path loss, AoA,      │              est_x, est_y (RSS-based estimate)
  [Anchor 3] ──┘      RTT, noise)            └──► Logged: RSS, AoA, RTT for MATLAB analysis
                  ▲
                  │ agent position (x,y)
                  └── from Agent (for channel simulation)
```

- **Anchor 1 / 2 / 3:** Fixed nodes; each outputs TX signals (WiFi, BLE) and position (X,Y).
- **Channel_And_Ranging:** Receives anchor TX and agent position; applies path loss, adds noise; outputs **RSS**, **AoA**, and **RTT** (round-trip time) for each link. *(After refactor this block may be named e.g. "Channel_And_Ranging" or "Signal_Generation_And_Noise".)*
- **Agent:** Receives RSS/AoA/RTT from Channel_And_Ranging; contains **ground-truth trajectory**, **RSS-based position estimation**, and **localization solver**; outputs **true_x, true_y** and **est_x, est_y** (and optionally logged signals for MATLAB).

Run **refactor_simulink_model.m** to apply meaningful block names and annotations (see end of this doc).

---

## 2. Logical grouping (subsystems)

| Group | Subsystem(s) | Role |
|-------|--------------|------|
| **Signal generation** | Anchor 1, 2, 3 | Source of TX signals and anchor positions. |
| **Channel + noise + ranging** | **Subsystem** → rename to **Channel_And_Ranging** | Path loss, AoA, RTT simulation; additive noise. Contains per-link blocks (e.g. Estimation_WiFi_1, Estimation_BLE_1, …). |
| **Estimation** | Inside **Agent**: RSS estimators (EstimateRSS 1..6), LocalizationSolver | Convert RSS/AoA/RTT to distances/angles; least-squares position. |
| **Filtering / state** | Inside **Agent**: Agent_positioning (ground truth), optional smoothing | Ground-truth trajectory; optional filtering before output. |

- **Signal flow in words:** Anchors generate TX → Channel_And_Ranging applies channel and outputs RSS/AoA/RTT → Agent uses these to compute **est_x, est_y** and outputs **true_x, true_y** from its trajectory.

---

## 3. Key outputs (for MATLAB)

- **Outports / logged signals** (used by `run_experiment` and config):
  - **true_x, true_y**: ground truth agent position.
  - **est_x, est_y**: RSS/AoA-derived position from the model.
  - **RSS:** e.g. estRSS1-3, estmRSS4-6 (names in `configs/localization_config.m`: `rss_names`).
  - **AoA:** AoA1_RX_wifi, AoA2_RX_wifi, AoA3_RX_wifi (`aoa_names`).
  - **RTT:** RTT_WIFI1-3, RTT_BLE1-3 (`rtt_names`).

Config signal names must match the model's outport/logged names.

---

## 4. Annotations (after running refactor script)

The refactor script adds short annotations on the canvas, for example:

- **Top level:** "Anchors → Channel_And_Ranging (path loss, AoA, RTT) → Agent (estimation). Outputs: true_x/y, est_x/y, RSS/AoA/RTT to workspace."
- **Inside Channel_And_Ranging:** "Per-link: TX + agent pos → path loss & noise → RSS, AoA, RTT."
- **Inside Agent:** "RSS/AoA/RTT in → RSS estimators + LocalizationSolver → est_x, est_y; Agent_positioning → true_x, true_y."

These are optional; the script places them so the diagram stays readable.

---

## 5. Apply renames and annotations (one-time)

From MATLAB:

1. `cd` to `LocalizationRSSandsub` (or add it to the path so the model is found).
2. Run: `refactor_simulink_model`
3. Save: `save_system('Localization_Ependorfv2')`

Optionally open the model first: `open_system('Localization_Ependorfv2')` to watch changes. Logged signal names (e.g. estRSS1, AoA1_RX_wifi) are unchanged, so `run_experiment` still works after the refactor.

The script:

- Renames blocks to meaningful names (e.g. **Subsystem** → **Channel_And_Ranging**, **EstimateRSS** → **RSS_Estimator_1**, **Esimation_WIFI_1** → **Estimation_WiFi_1**).
- Adds annotations explaining signal flow and grouping.
- Does **not** change connections or algorithm logic.

If you prefer to keep the original block names, you can still use this guide and only add annotations by editing the script to skip the rename section.

---

## 6. Facts read from the model file (`Localization_Ependorfv2.slx`)

The `.slx` is a zip of XML; the values below were read from it directly (not assumed).

**Anchors** (`Constant` blocks `Anchor k_X` / `Anchor k_Y`): Anchor 1 = (0, 0) m, Anchor 2 = (0, 5) m, Anchor 3 = (5, 0) m. `cfg.anchor_pos` defaults to these, and `run_experiment` re-reads them from the loaded model (`sync_anchors_with_model`). Earlier versions of the config listed (1,3), (5,7), (10,11), which made the MATLAB AoA/RTT results wrong.

**Channel charts** (`applyPathLossWithAOA_WiFi` / `_BLE`, one per link; distance clamped at 1 m, `Ptx = 0 dBm`):

| | PL0 [dB] | n | AoA noise | RTT noise | RTT |
|---|---|---|---|---|---|
| WiFi | 30 | 2.2 | 2° | 1 ns | `2d/c + noise` |
| BLE | 50 | 3.0 | 5° | 5 ns | `2d/c + noise` |

These are `cfg.channel.wifi` / `cfg.channel.ble`.

**Estimator charts** (`EstimateRSSAOARTT`, six copies inside `Agent`) add a further 1.5 dB RSS noise, 2° AoA noise and 2 ns RTT noise to their inputs.

**`LocalizationSolver` chart** (produces `est_x`, `est_y`): minimises with `fminsearch`
`1.0 * sum (d_model - d_rss)^2 + 0.5 * sum (angle error in degrees)^2 + 0.5 * sum (d_model - d_rtt)^2`
over all six links (WiFi + BLE, anchors duplicated). So `est_x/est_y` is a **combined RSS + AoA + RTT estimate**, not an RSS-only one. RSS is converted to distance with one fixed model, `PL0 = 44 dB`, `n = 1.9`, for every link, which does not match the channel (WiFi 30/2.2, BLE 50/3.0), so the RSS ranges are biased. The previous solution is used as the initial guess of the next step (`persistent`).

**Solver:** variable-step, stop time 10 s.

**Logging:** `cfg.aoa_names` / `cfg.rtt_names` match the output port names of the channel subsystem; the exact point at which each signal is logged was not verified from the XML.

### Seeding

The noise comes from `randn` in the MATLAB Function blocks. Whether `rng(seed)` in MATLAB makes it repeatable depends on the release; run `check_reproducibility` once. For repeatable experiments use `run_simulated_experiment` / `run_monte_carlo`, which model the same channel in MATLAB with their own seeded `RandStream`.

