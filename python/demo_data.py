#!/usr/bin/env python3
"""
Write a results folder in exactly the format the MATLAB code produces, using the
Python reference implementation (locref.py). Lets you try python/dashboard.py
and python/evaluate_from_matlab_results.py without MATLAB.

Files written (same names/columns as MATLAB's run_evaluation_report,
run_monte_carlo and run_sweep):
  cfg.json, metrics.csv, evaluation_timeseries.csv,
  mc_summary.csv, mc_errors.csv, sweep_<param>.csv

Usage:
  python demo_data.py                       # -> results/python_demo/
  python demo_data.py --out some/folder --runs 30
"""

import argparse
import copy
import json
from pathlib import Path

import numpy as np
import pandas as pd

import locref as L


def timeseries_frame(meas: dict, res: dict) -> pd.DataFrame:
    cols = {"index": np.arange(1, res["N"] + 1), "t": meas["t"],
            "true_x": meas["true_x"], "true_y": meas["true_y"]}
    for k in L.METHODS:
        cols[f"{k}_x"] = res["est"][k]["x"]
        cols[f"{k}_y"] = res["est"][k]["y"]
    for k in L.METHODS:
        cols[f"err_{k}"] = res["err"][k]
    return pd.DataFrame(cols)


def metrics_frame(res: dict, target: float) -> pd.DataFrame:
    rows = []
    for k, name in L.METHODS.items():
        e = res["err"][k]
        if not np.isfinite(e).any():
            continue
        s = L.error_stats(e, target)
        rows.append({"method": k, "name": name, "mean_m": s["mean"], "median_m": s["median"],
                     "p90_m": s["p90"], "max_m": s["max"], "min_m": float(np.nanmin(e)),
                     "std_m": s["std"], "rmse_m": s["rmse"],
                     "frac_under_target": s["frac_under_target"], "n": s["n"]})
    return pd.DataFrame(rows)


def mc_frames(mc: dict, t: np.ndarray):
    summ = []
    long = []
    for k, name in L.METHODS.items():
        s = mc["summary"][k]
        if s["n"] == 0:
            continue
        summ.append({"method": k, "name": name, "mean_m": s["mean"], "mean_ci95_m": s["mean_ci95"],
                     "median_m": s["median"], "p90_m": s["p90"], "max_m": s["max"], "std_m": s["std"],
                     "rmse_m": s["rmse"], "frac_under_target": s["frac_under_target"], "n": s["n"]})
        E = mc["errors"][k]
        runs, N = E.shape
        long.append(pd.DataFrame({
            "run": np.repeat(np.arange(1, runs + 1), N), "step": np.tile(np.arange(1, N + 1), runs),
            "t": np.tile(t, runs), "method": k, "err_m": E.ravel()}))
    return pd.DataFrame(summ), pd.concat(long, ignore_index=True)


def sweep_frame(rows) -> pd.DataFrame:
    df = pd.DataFrame(rows)
    df["value_num"] = pd.to_numeric(df["value"], errors="coerce")
    df["value"] = df["value"].astype(str)
    df = df.rename(columns={"mean": "mean_err", "mean_ci95": "ci95", "median": "median_err",
                            "p90": "p90_err", "rmse": "rmse_err"})
    return df[["param", "value", "value_num", "method", "mean_err", "ci95",
               "median_err", "p90_err", "rmse_err", "frac_under_target"]]


def write_demo(out: Path, runs: int = 30, sweep_runs: int = 10, seed: int = 42) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    cfg = L.default_cfg()
    cfg["random_seed"] = seed

    meas = L.simulate_scenario(cfg, seed)
    res = L.analyze_run(meas, cfg)
    timeseries_frame(meas, res).to_csv(out / "evaluation_timeseries.csv", index=False)
    metrics_frame(res, cfg["target_error_m"]).to_csv(out / "metrics.csv", index=False)
    (out / "cfg.json").write_text(json.dumps(L.cfg_to_jsonable(cfg), indent=2))

    mc = L.monte_carlo(cfg, runs, seed)
    summ, long = mc_frames(mc, meas["t"])
    summ.to_csv(out / "mc_summary.csv", index=False)
    long.to_csv(out / "mc_errors.csv", index=False)

    sweeps = {
        "noise_scale.aoa": [0.5, 1, 2, 4],
        "noise_scale.rtt": [0.5, 1, 2, 4, 8],
        "noise_scale.rss": [0.5, 1, 2, 4],
        "anchor_layout": ["model", "triangle", "four_corners", "collinear"],
    }
    for param, values in sweeps.items():
        rows = L.sweep(copy.deepcopy(cfg), param, values, sweep_runs)
        sweep_frame(rows).to_csv(out / f"sweep_{param.replace('.', '_')}.csv", index=False)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=None, help="output folder (default: <repo>/results/python_demo)")
    ap.add_argument("--runs", type=int, default=30, help="Monte Carlo runs")
    ap.add_argument("--sweep-runs", type=int, default=10, help="Monte Carlo runs per sweep value")
    args = ap.parse_args()
    repo = Path(__file__).resolve().parent.parent
    out = Path(args.out) if args.out else repo / "results" / "python_demo"
    write_demo(out, args.runs, args.sweep_runs)
    print(f"Wrote demo results to {out}")


if __name__ == "__main__":
    main()
