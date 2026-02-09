#!/usr/bin/env python3
"""
Load MATLAB-generated evaluation data and recompute metrics + visualizations.

Expects a results folder (e.g. results/20250209_143022) that contains
evaluation_timeseries.csv produced by run_evaluation_report.m. Optionally
reads metrics.csv to compare recomputed stats.

Usage:
  python evaluate_from_matlab_results.py                    # use latest results/
  python evaluate_from_matlab_results.py results/20250209_143022
  python evaluate_from_matlab_results.py --save              # save figures into that folder
"""

import argparse
import sys
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# Error columns in evaluation_timeseries.csv: each is instantaneous Euclidean (L2) position
# error in metres (one value per timestep).
ERROR_COLUMNS = ["err_smooth", "err_kf", "err_aoa", "err_rtt", "err_fused"]
POSITION_COLUMNS = ["true_x", "true_y", "kf_x", "kf_y", "est_aoa_x", "est_aoa_y", "est_rtt_x", "est_rtt_y", "fused_x", "fused_y"]


def find_latest_results_dir(repo_root: Path) -> Optional[Path]:
    results_dir = repo_root / "results"
    if not results_dir.is_dir():
        return None
    subdirs = sorted([d for d in results_dir.iterdir() if d.is_dir()], reverse=True)
    for d in subdirs:
        csv_path = d / "evaluation_timeseries.csv"
        if csv_path.exists():
            return d
    return None


def load_timeseries(path: Path) -> pd.DataFrame:
    path = Path(path)
    csv_path = path / "evaluation_timeseries.csv" if path.is_dir() else path
    if not csv_path.exists():
        raise FileNotFoundError(f"Not found: {csv_path}")
    return pd.read_csv(csv_path)


def recompute_stats(df: pd.DataFrame) -> pd.DataFrame:
    """Compute mean, median, max, min, std over time for each error column (aggregated stats).
    Input columns are instantaneous L2 errors in [m]; output stats are in [m]."""
    stats = []
    for col in ERROR_COLUMNS:
        if col not in df.columns:
            continue
        ser = df[col].dropna()
        ser = ser[np.isfinite(ser)]
        if ser.empty:
            stats.append({"method": col.replace("err_", ""), "mean_m": np.nan, "median_m": np.nan, "max_m": np.nan, "min_m": np.nan, "std_m": np.nan})
        else:
            stats.append({
                "method": col.replace("err_", ""),
                "mean_m": float(ser.mean()),
                "median_m": float(ser.median()),
                "max_m": float(ser.max()),
                "min_m": float(ser.min()),
                "std_m": float(ser.std(ddof=1)),
            })
    return pd.DataFrame(stats)


def plot_trajectory(df: pd.DataFrame, save_path: Optional[Path] = None) -> None:
    fig, ax = plt.subplots(1, 1, figsize=(8, 6))
    ax.plot(df["true_x"], df["true_y"], "k-", lw=1.5, label="Ground truth")
    if "kf_x" in df.columns:
        ax.plot(df["kf_x"], df["kf_y"], "g--", label="RSS Kalman", alpha=0.9)
    if "est_aoa_x" in df.columns and df["est_aoa_x"].notna().any():
        ax.plot(df["est_aoa_x"], df["est_aoa_y"], "r--", label="AoA WLS", alpha=0.9)
    if "est_rtt_x" in df.columns and df["est_rtt_x"].notna().any():
        ax.plot(df["est_rtt_x"], df["est_rtt_y"], "b--", label="RTT", alpha=0.9)
    if "fused_x" in df.columns and df["fused_x"].notna().any():
        ax.plot(df["fused_x"], df["fused_y"], "m-", lw=1.2, label="Fusion")
    ax.set_xlabel("x (m)")
    ax.set_ylabel("y (m)")
    ax.set_title("Trajectory (Python from MATLAB data)")
    ax.legend(loc="best")
    ax.grid(True)
    ax.axis("equal")
    plt.tight_layout()
    if save_path:
        fig.savefig(save_path, dpi=150)
        plt.close(fig)
    else:
        plt.show()


def plot_error_histograms(df: pd.DataFrame, save_path: Optional[Path] = None) -> None:
    cols = [c for c in ERROR_COLUMNS if c in df.columns]
    n = len(cols)
    if n == 0:
        print("No error columns found for histograms.")
        return
    nrows = 2
    ncols = (n + 1) // 2
    fig, axes = plt.subplots(nrows, ncols, figsize=(5 * ncols, 4 * nrows))
    if n == 1:
        axes = np.array([axes])
    axes = axes.flatten()
    for i, col in enumerate(cols):
        ser = df[col].dropna()
        ser = ser[np.isfinite(ser)]
        axes[i].hist(ser, bins=20, alpha=0.7, edgecolor="k")
        axes[i].set_xlabel("Error (m)")
        axes[i].set_ylabel("Count")
        axes[i].set_title(col.replace("err_", ""))
        axes[i].grid(True, alpha=0.3)
    for j in range(i + 1, len(axes)):
        axes[j].set_visible(False)
    fig.suptitle("Localization error histograms (Python from MATLAB data)")
    plt.tight_layout()
    if save_path:
        fig.savefig(save_path, dpi=150)
        plt.close(fig)
    else:
        plt.show()


def main() -> int:
    parser = argparse.ArgumentParser(description="Recompute metrics and plots from MATLAB evaluation CSV.")
    parser.add_argument("path", nargs="?", default=None, help="Results folder (e.g. results/20250209_143022) or path to evaluation_timeseries.csv")
    parser.add_argument("--save", action="store_true", help="Save figures into the results folder")
    parser.add_argument("--no-plot", action="store_true", help="Only print stats, do not open or save plots")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    if args.path:
        path = Path(args.path)
        if not path.is_absolute():
            path = (repo_root / path).resolve()
    else:
        path = find_latest_results_dir(repo_root)
        if path is None:
            print("No results folder with evaluation_timeseries.csv found. Run MATLAB run_experiment first.", file=sys.stderr)
            return 1

    try:
        df = load_timeseries(path)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    stats = recompute_stats(df)
    print("Recomputed metrics (Python):")
    print(stats.to_string(index=False))
    print()

    results_dir = path if path.is_dir() else path.parent
    if args.save and results_dir.is_dir():
        stats.to_csv(results_dir / "metrics_python.csv", index=False)
        plot_trajectory(df, save_path=results_dir / "trajectory_python.png")
        plot_error_histograms(df, save_path=results_dir / "error_histograms_python.png")
        print(f"Saved metrics_python.csv, trajectory_python.png, error_histograms_python.png in {results_dir}")
    elif not args.no_plot:
        plot_trajectory(df, save_path=None)
        plot_error_histograms(df, save_path=None)

    return 0


if __name__ == "__main__":
    sys.exit(main())
