# Legacy scripts

Superseded by the pipeline in the repository root (`run_experiment`, `analyze_run`, ...). Kept for reference only; they are **not** on the MATLAB path and are not maintained.

- `analyze_localization_resultsv2.m` – the original 388‑line monolithic analysis. Note it hard‑codes anchors (1,3), (5,7), (10,11), which do **not** match the Simulink model's (0,0), (0,5), (5,0); its AoA and RTT results are therefore wrong.
- `run_localization_analysis.m` – thin wrapper that called `run_experiment`.
- `testapplypathloss.m`, `test_applyPathLossWithAOA.m` – ad‑hoc smoke tests; replaced by `tests/TestConfig.m` (`pathLossSmokeTest`).
