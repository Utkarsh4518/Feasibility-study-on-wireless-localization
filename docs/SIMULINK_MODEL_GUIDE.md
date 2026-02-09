# Simulink Model Guide — 5-Minute Overview

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
  - **true_x, true_y** — ground truth agent position.
  - **est_x, est_y** — RSS/AoA-derived position from the model.
  - **RSS:** e.g. estRSS1–3, estmRSS4–6 (names in `configs/localization_config.m`: `rss_names`).
  - **AoA:** AoA1_RX_wifi, AoA2_RX_wifi, AoA3_RX_wifi (`aoa_names`).
  - **RTT:** RTT_WIFI1–3, RTT_BLE1–3 (`rtt_names`).

Config signal names must match the model’s outport/logged names.

---

## 4. Annotations (after running refactor script)

The refactor script adds short annotations on the canvas, for example:

- **Top level:** “Anchors → Channel_And_Ranging (path loss, AoA, RTT) → Agent (estimation). Outputs: true_x/y, est_x/y, RSS/AoA/RTT to workspace.”
- **Inside Channel_And_Ranging:** “Per-link: TX + agent pos → path loss & noise → RSS, AoA, RTT.”
- **Inside Agent:** “RSS/AoA/RTT in → RSS estimators + LocalizationSolver → est_x, est_y; Agent_positioning → true_x, true_y.”

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
