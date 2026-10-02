#!/usr/bin/env python3
"""
Recompute metrics and redraw figures from a MATLAB results folder.

Reads evaluation_timeseries.csv (written by run_evaluation_report.m) from a
results folder such as results/20260101_120000_sim. Columns: index, t, true_x,
true_y, then per method <key>_x, <key>_y and err_<key> (instantaneous Euclidean
error in metres). Method keys: rss, rss_smooth, rss_kf, aoa, rtt, fusion, ekf.

Usage:
  python evaluate_from_matlab_results.py                  # latest results folder
  python evaluate_from_matlab_results.py results/<folder>
  python evaluate_from_matlab_results.py --save           # write PNGs + metrics_python.csv
  python evaluate_from_matlab_results.py --html           # also build the Plotly dashboard
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import locref as L

COLORS = {"rss": "#808080", "rss_smooth": "#57B5E8", "rss_kf": "#009E73", "aoa": "#D55E00",
          "rtt": "#0072B2", "fusion": "#CC79A7", "ekf": "#000000"}


def find_latest_results_dir(repo_root: Path) -> Optional[Path]:
    results_dir = repo_root / "results"
    if not results_dir.is_dir():
        return None
    for d in sorted([d for d in results_dir.iterdir() if d.is_dir()], reverse=True):
        if (d / "evaluation_timeseries.csv").exists():
            return d
    return None


def load_timeseries(path: Path) -> pd.DataFrame:
    csv_path = path / "evaluation_timeseries.csv" if path.is_dir() else path
    if not csv_path.exists():
        raise FileNotFoundError(f"Not found: {csv_path}")
    return pd.read_csv(csv_path)


def present_methods(df: pd.DataFrame):
    return [k for k in L.METHODS if f"err_{k}" in df.columns and df[f"err_{k}"].notna().any()]


def recompute_stats(df: pd.DataFrame, target: float = 0.5) -> pd.DataFrame:
    rows = []
    for k in present_methods(df):
        s = L.error_stats(df[f"err_{k}"].to_numpy(), target)
        rows.append({"method": k, "name": L.METHODS[k], "mean_m": s["mean"], "median_m": s["median"],
                     "p90_m": s["p90"], "max_m": s["max"], "std_m": s["std"], "rmse_m": s["rmse"],
                     "frac_under_target": s["frac_under_target"], "n": s["n"]})
    return pd.DataFrame(rows)


def plot_cdf(df: pd.DataFrame, target: float, save_path: Optional[Path]) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 4.6))
    xmax = 0.0
    for k in present_methods(df):
        e = np.sort(df[f"err_{k}"].dropna().to_numpy())
        ax.step(np.concatenate([[0], e]), np.concatenate([[0], np.arange(1, len(e) + 1) / len(e)]), where="post",
                color=COLORS[k], lw=2.6 if k in ("fusion", "ekf") else 1.6,
                label=f"{L.METHODS[k]} ({100 * np.mean(e <= target):.0f}% ≤ {target:g} m)")
        xmax = max(xmax, np.percentile(e, 99))
    ax.axvline(target, color="0.25", ls="--", lw=1.2)
    ax.set(xlim=(0, max(1.1 * xmax, 1.5 * target)), ylim=(0, 1), xlabel="Position error [m]",
           ylabel="Cumulative probability", title="Position error distribution (simulation)")
    ax.grid(alpha=0.2)
    ax.legend(loc="lower right", frameon=False, fontsize=9)
    fig.tight_layout()
    _finish(fig, save_path)


def plot_trajectory_panels(df: pd.DataFrame, anchors: Optional[np.ndarray], target: float,
                           save_path: Optional[Path]) -> None:
    keys = [k for k in ("rss", "rss_kf", "aoa", "rtt", "fusion", "ekf") if k in present_methods(df)]
    n = len(keys)
    cols = 3 if n > 4 else 2
    rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(4.2 * cols, 3.8 * rows), squeeze=False)
    sc = None
    for ax, k in zip(axes.ravel(), keys):
        ax.plot(df["true_x"], df["true_y"], color="0.8", lw=4, zorder=1)
        sc = ax.scatter(df[f"{k}_x"], df[f"{k}_y"], c=df[f"err_{k}"], s=14, cmap="viridis",
                        vmin=0, vmax=2 * target, zorder=2)
        if anchors is not None:
            ax.plot(anchors[:, 0], anchors[:, 1], "ks", ms=7, zorder=3)
        ax.set_title(f"{L.METHODS[k]} (mean {df[f'err_{k}'].mean():.2f} m)", fontsize=10)
        ax.set_aspect("equal")
        ax.grid(alpha=0.2)
    for ax in axes.ravel()[n:]:
        ax.set_visible(False)
    if sc is not None:
        fig.colorbar(sc, ax=axes.ravel().tolist(), label="Position error [m]", shrink=0.8)
    _finish(fig, save_path)


def _finish(fig, save_path: Optional[Path]) -> None:
    if save_path:
        fig.savefig(save_path, dpi=200, bbox_inches="tight")
        plt.close(fig)
    else:
        plt.show()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", nargs="?", help="results folder or path to evaluation_timeseries.csv")
    ap.add_argument("--save", action="store_true", help="save figures and metrics_python.csv in the folder")
    ap.add_argument("--no-plot", action="store_true", help="only print stats")
    ap.add_argument("--html", action="store_true", help="also build dashboard.html")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    if args.path:
        path = Path(args.path)
        if not path.is_absolute():
            path = (Path.cwd() / path).resolve()
    else:
        path = find_latest_results_dir(repo_root)
        if path is None:
            print("No results folder with evaluation_timeseries.csv found. Run MATLAB first.", file=sys.stderr)
            return 1
    try:
        df = load_timeseries(path)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    folder = path if path.is_dir() else path.parent
    anchors, target = None, 0.5
    if (folder / "cfg.json").exists():
        cfg = L.cfg_from_json(json.loads((folder / "cfg.json").read_text()))
        anchors, target = cfg["anchor_pos"], cfg["target_error_m"]

    stats = recompute_stats(df, target)
    print("Recomputed metrics (Python):")
    print(stats.drop(columns=["method"]).to_string(index=False, float_format=lambda v: f"{v:.3f}"))

    if args.save:
        stats.to_csv(folder / "metrics_python.csv", index=False)
        plot_cdf(df, target, folder / "cdf_python.png")
        plot_trajectory_panels(df, anchors, target, folder / "trajectory_python.png")
        print(f"Saved metrics_python.csv, cdf_python.png, trajectory_python.png in {folder}")
    elif not args.no_plot:
        plot_cdf(df, target, None)
        plot_trajectory_panels(df, anchors, target, None)

    if args.html:
        import dashboard
        print(f"Wrote {dashboard.build(folder)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
