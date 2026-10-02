#!/usr/bin/env python3
"""
Interactive HTML report (Plotly) from a results folder.

Reads whatever is present in the folder (all produced by the MATLAB code, or by
demo_data.py):
  cfg.json                    -> anchors, target, error-bound map
  evaluation_timeseries.csv   -> trajectory explorer, error over time vs bound
  metrics.csv                 -> single-run table
  mc_errors.csv, mc_summary.csv -> CDF, box plot, Monte Carlo table
  sweep_*.csv                 -> sensitivity charts

Usage:
  python dashboard.py results/20260101_120000_sim      # -> <folder>/dashboard.html
  python dashboard.py --demo                           # build demo data + report
  python dashboard.py <folder> --offline               # embed plotly.js (no CDN)
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd
import plotly.graph_objects as go

import locref as L

# Same colours as MATLAB's method_info (Okabe-Ito, colour-blind safe)
COLORS = {
    "rss": "#808080", "rss_smooth": "#57B5E8", "rss_kf": "#009E73", "aoa": "#D55E00",
    "rtt": "#0072B2", "fusion": "#CC79A7", "ekf": "#000000",
}
NAMES = dict(L.METHODS)
FONT = dict(family="Inter, Segoe UI, Helvetica, Arial, sans-serif", size=13)


def _layout(fig: go.Figure, title: str, height: int = 460, **kw) -> go.Figure:
    fig.update_layout(title=dict(text=title, x=0.01, font=dict(size=16)), height=height, font=FONT,
                      margin=dict(l=60, r=20, t=60, b=50), template="plotly_white",
                      legend=dict(orientation="h", y=-0.2), **kw)
    return fig


def _present(df: pd.DataFrame, methods: List[str], suffix_cols=("err_",)) -> List[str]:
    return [m for m in methods if f"err_{m}" in df.columns and df[f"err_{m}"].notna().any()]


# ---------------------------------------------------------------- figures
def fig_cdf(errs: Dict[str, np.ndarray], target: float, title: str) -> go.Figure:
    fig = go.Figure()
    xmax = 0.0
    for k in NAMES:
        if k not in errs:
            continue
        e = np.sort(errs[k][np.isfinite(errs[k])])
        if e.size == 0:
            continue
        frac = float(np.mean(e <= target))
        fig.add_trace(go.Scatter(
            x=np.concatenate([[0], e]), y=np.concatenate([[0], np.arange(1, e.size + 1) / e.size]),
            mode="lines", line=dict(color=COLORS[k], width=3 if k in ("fusion", "ekf") else 1.8, shape="hv"),
            name=f"{NAMES[k]} ({100 * frac:.0f}% ≤ {target:g} m)",
            hovertemplate="error ≤ %{x:.3f} m for %{y:.1%}<extra>" + NAMES[k] + "</extra>"))
        xmax = max(xmax, float(np.percentile(e, 99)))
    fig.add_vline(x=target, line=dict(color="#444", dash="dash"), annotation_text=f"{target:g} m target",
                  annotation_position="bottom right")
    fig.update_xaxes(title="Position error [m]", range=[0, max(xmax * 1.1, 1.5 * target)])
    fig.update_yaxes(title="Cumulative probability", range=[0, 1.01])
    return _layout(fig, title)


def fig_box(errs: Dict[str, np.ndarray], target: float, title: str) -> go.Figure:
    fig = go.Figure()
    for k in NAMES:
        if k not in errs or not np.isfinite(errs[k]).any():
            continue
        e = errs[k][np.isfinite(errs[k])]
        fig.add_trace(go.Box(y=e, name=NAMES[k], marker_color=COLORS[k], boxmean=True,
                             boxpoints=False, line=dict(width=1.5)))
    fig.add_hline(y=target, line=dict(color="#444", dash="dash"), annotation_text=f"{target:g} m target",
                  annotation_position="top left")
    fig.update_yaxes(title="Position error [m]", rangemode="tozero")
    return _layout(fig, title, showlegend=False)


def fig_trajectory(ts: pd.DataFrame, anchors: np.ndarray, target: float) -> go.Figure:
    methods = [m for m in NAMES if f"{m}_x" in ts.columns and ts[f"{m}_x"].notna().any()
               and m not in ("rss_smooth",)]
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=ts["true_x"], y=ts["true_y"], mode="lines", name="Ground truth",
                             line=dict(color="#C8C8C8", width=7), hoverinfo="skip"))
    for i, k in enumerate(methods):
        fig.add_trace(go.Scatter(
            x=ts[f"{k}_x"], y=ts[f"{k}_y"], mode="markers", name=NAMES[k], visible=(i == len(methods) - 1),
            marker=dict(size=8, color=ts[f"err_{k}"], colorscale="Viridis", cmin=0, cmax=2 * target,
                        colorbar=dict(title="Error [m]"), line=dict(width=0.5, color="white")),
            customdata=np.column_stack([ts["t"], ts[f"err_{k}"]]),
            hovertemplate="t=%{customdata[0]:.1f} s<br>x=%{x:.2f}, y=%{y:.2f}<br>error %{customdata[1]:.3f} m<extra></extra>"))
    fig.add_trace(go.Scatter(x=anchors[:, 0], y=anchors[:, 1], mode="markers+text", name="Anchors",
                             text=[f"A{i + 1}" for i in range(len(anchors))], textposition="top right",
                             marker=dict(symbol="square", size=11, color="black")))
    n = len(methods)
    buttons = []
    for i, k in enumerate(methods):
        vis = [True] + [j == i for j in range(n)] + [True]
        buttons.append(dict(label=NAMES[k], method="update", args=[{"visible": vis}]))
    fig.update_layout(updatemenus=[dict(type="dropdown", buttons=buttons, x=1.0, xanchor="right", y=1.13, yanchor="top", active=n - 1)])
    fig.update_xaxes(title="x [m]", scaleanchor="y", scaleratio=1)
    fig.update_yaxes(title="y [m]")
    return _layout(fig, "Estimated path (colour = error)", height=560)


def fig_error_time(ts: pd.DataFrame, cfg: dict) -> go.Figure:
    fig = go.Figure()
    bound = L.crlb_over_time(cfg, ts["true_x"].to_numpy(), ts["true_y"].to_numpy())
    fig.add_trace(go.Scatter(x=ts["t"], y=bound, mode="lines", name="RMSE lower bound (snapshot)",
                             fill="tozeroy", line=dict(color="rgba(150,150,150,0.8)", width=1),
                             fillcolor="rgba(200,200,200,0.5)"))
    for k in ("aoa", "rtt", "fusion", "ekf"):
        if f"err_{k}" in ts.columns and ts[f"err_{k}"].notna().any():
            fig.add_trace(go.Scatter(x=ts["t"], y=ts[f"err_{k}"], mode="lines", name=NAMES[k],
                                     line=dict(color=COLORS[k], width=2)))
    fig.add_hline(y=cfg["target_error_m"], line=dict(color="#444", dash="dash"))
    fig.update_xaxes(title="Time [s]")
    fig.update_yaxes(title="Position error [m]", rangemode="tozero")
    return _layout(fig, "Error over time vs theoretical lower bound")


def fig_bound_map(cfg: dict, ts: Optional[pd.DataFrame]) -> go.Figure:
    A = cfg["anchor_pos"]
    pad = 1.5
    xs = np.linspace(A[:, 0].min() - pad, A[:, 0].max() + pad, 60)
    ys = np.linspace(A[:, 1].min() - pad, A[:, 1].max() + pad, 60)
    Z = L.crlb_map(cfg, xs, ys)
    t = cfg["target_error_m"]
    zmax = max(float(np.nanpercentile(Z, 98)), 1e-3)
    has_contour = np.nanmin(Z) < t < np.nanmax(Z)
    fig = go.Figure()
    fig.add_trace(go.Heatmap(x=xs, y=ys, z=Z, zmin=0, zmax=zmax, colorscale="Viridis",
                             colorbar=dict(title="Bound [m]"),
                             hovertemplate="x=%{x:.2f}, y=%{y:.2f}<br>bound %{z:.3f} m<extra></extra>"))
    if has_contour:
        fig.add_trace(go.Contour(x=xs, y=ys, z=Z, showscale=False, hoverinfo="skip",
                                 contours=dict(start=t, end=t, size=1, coloring="none"),
                                 line=dict(color="white", width=2), name=f"{t:g} m"))
    if ts is not None:
        fig.add_trace(go.Scatter(x=ts["true_x"], y=ts["true_y"], mode="lines", name="Path",
                                 line=dict(color="#D55E00", width=3)))
    fig.add_trace(go.Scatter(x=A[:, 0], y=A[:, 1], mode="markers+text", name="Anchors",
                             text=[f"A{i + 1}" for i in range(len(A))], textposition="top right",
                             textfont=dict(color="white"),
                             marker=dict(symbol="square", size=11, color="black", line=dict(color="white", width=1))))
    fig.update_xaxes(title="x [m]", scaleanchor="y", scaleratio=1, range=[xs[0], xs[-1]])
    fig.update_yaxes(title="y [m]", range=[ys[0], ys[-1]])
    note = (f"white contour = {t:g} m target" if has_contour
            else f"below the {t:g} m target everywhere (max {np.nanmax(Z):.2f} m)")
    return _layout(fig, f"Best achievable accuracy – layout “{cfg.get('anchor_layout', '')}”, {note}",
                   height=560)


def fig_sweep(df: pd.DataFrame, target: float) -> go.Figure:
    fig = go.Figure()
    numeric = df["value_num"].notna().all()
    for k in ("aoa", "rtt", "fusion", "ekf"):
        d = df[df["method"] == k]
        if d.empty:
            continue
        if numeric:
            d = d.sort_values("value_num")
            x = d["value_num"]
        else:
            order = list(dict.fromkeys(df["value"]))
            d = d.assign(_o=d["value"].map(order.index)).sort_values("_o")
            x = d["value"]
        fig.add_trace(go.Scatter(x=x, y=d["mean_err"], mode="lines+markers", name=NAMES[k],
                                 line=dict(color=COLORS[k], width=2.4), marker=dict(size=8),
                                 error_y=dict(type="data", array=d["ci95"].fillna(0), visible=True, thickness=1.2)))
    fig.add_hline(y=target, line=dict(color="#444", dash="dash"))
    fig.update_xaxes(title=df["param"].iloc[0], type="category" if not numeric else "linear")
    fig.update_yaxes(title="Mean position error [m]", rangemode="tozero")
    return _layout(fig, f"Sensitivity: {df['param'].iloc[0]} (mean ± 95% CI over runs)")


# ---------------------------------------------------------------- tables
def _table_html(df: pd.DataFrame, fmt: Dict[str, str]) -> str:
    head = "".join(f"<th>{c}</th>" for c in df.columns)
    rows = []
    for _, r in df.iterrows():
        cells = []
        for c in df.columns:
            v = r[c]
            cells.append(f"<td>{fmt[c].format(v) if c in fmt and pd.notna(v) else v}</td>")
        rows.append("<tr>" + "".join(cells) + "</tr>")
    return f"<table><thead><tr>{head}</tr></thead><tbody>{''.join(rows)}</tbody></table>"


def _summary_table(df: pd.DataFrame, ci: bool) -> str:
    cols = ["name", "mean_m"] + (["mean_ci95_m"] if ci and "mean_ci95_m" in df else []) + \
           ["median_m", "p90_m", "rmse_m", "frac_under_target"]
    d = df[[c for c in cols if c in df.columns]].copy()
    if "frac_under_target" in d:
        d["frac_under_target"] = d["frac_under_target"] * 100
    d = d.rename(columns={"name": "Method", "mean_m": "Mean [m]", "mean_ci95_m": "±95% CI [m]",
                          "median_m": "Median [m]", "p90_m": "P90 [m]", "rmse_m": "RMSE [m]",
                          "frac_under_target": "≤ target [%]"})
    fmt = {c: "{:.3f}" for c in d.columns if c not in ("Method", "≤ target [%]")}
    fmt["≤ target [%]"] = "{:.1f}"
    return _table_html(d, fmt)


CSS = """
:root{--bg:#fff;--fg:#1d2330;--mut:#5b6577;--card:#f5f7fa;--line:#e1e5ec}
@media (prefers-color-scheme:dark){:root{--bg:#12151c;--fg:#e8ebf2;--mut:#9aa4b8;--card:#1a1f2a;--line:#2a3140}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 Inter,Segoe UI,Helvetica,Arial,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:26px;margin:0 0 4px}h2{font-size:19px;margin:36px 0 8px}p.sub{color:var(--mut);margin:0 0 20px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin:18px 0}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.kpi b{display:block;font-size:24px}.kpi span{color:var(--mut);font-size:13px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px;margin:10px 0;overflow-x:auto}
.card.plot{background:#fff;color:#1d2330}
table{border-collapse:collapse;width:100%}th,td{padding:7px 10px;text-align:right;border-bottom:1px solid var(--line)}
th:first-child,td:first-child{text-align:left}th{color:var(--mut);font-weight:600;font-size:13px}
.note{color:var(--mut);font-size:13px}
@media (max-width:600px){h1{font-size:21px}}
"""


def build(folder: Path, offline: bool = False) -> Path:
    cfg = None
    if (folder / "cfg.json").exists():
        cfg = L.cfg_from_json(json.loads((folder / "cfg.json").read_text()))
    ts = pd.read_csv(folder / "evaluation_timeseries.csv") if (folder / "evaluation_timeseries.csv").exists() else None
    metrics = pd.read_csv(folder / "metrics.csv") if (folder / "metrics.csv").exists() else None
    mc_err = pd.read_csv(folder / "mc_errors.csv") if (folder / "mc_errors.csv").exists() else None
    mc_sum = pd.read_csv(folder / "mc_summary.csv") if (folder / "mc_summary.csv").exists() else None
    sweeps = sorted(folder.glob("sweep_*.csv"))
    if ts is None and mc_err is None:
        raise SystemExit(f"No evaluation_timeseries.csv or mc_errors.csv in {folder}")
    target = cfg["target_error_m"] if cfg else 0.5
    cfg = cfg or L.default_cfg()

    first = [True]

    def div(fig: go.Figure) -> str:
        inc = ("cdn" if not offline else True) if first[0] else False
        first[0] = False
        body = fig.to_html(full_html=False, include_plotlyjs=inc, config=dict(displaylogo=False, responsive=True))
        return f"<div class='card plot'>{body}</div>"

    parts: List[str] = []
    best = mc_sum if mc_sum is not None else metrics
    if best is not None and not best.empty:
        kp = []
        for k in ("ekf", "fusion", "rtt", "aoa"):
            r = best[best["method"] == k]
            if r.empty:
                continue
            r = r.iloc[0]
            kp.append(f"<div class='kpi'><b>{r['mean_m']:.2f} m</b><span>{NAMES[k]} – mean error"
                      f"<br>{100 * r['frac_under_target']:.0f}% of samples ≤ {target:g} m</span></div>")
        parts.append(f"<div class='kpis'>{''.join(kp)}</div>")

    if mc_sum is not None:
        parts.append("<h2>Monte Carlo summary</h2><div class='card'>" + _summary_table(mc_sum, True) + "</div>")
    elif metrics is not None:
        parts.append("<h2>Single-run summary</h2><div class='card'>" + _summary_table(metrics, False) + "</div>")

    if mc_err is not None:
        errs = {k: g["err_m"].to_numpy() for k, g in mc_err.groupby("method")}
        n_runs = mc_err["run"].nunique()
        parts.append("<h2>How often is each method accurate enough?</h2>" + div(fig_cdf(errs, target, f"Error distribution ({n_runs} Monte Carlo runs)")))
        parts.append(div(fig_box(errs, target, "Error per method")))
    elif ts is not None:
        errs = {m: ts[f"err_{m}"].to_numpy() for m in NAMES if f"err_{m}" in ts.columns}
        parts.append("<h2>Error distribution</h2>" + div(fig_cdf(errs, target, "Error distribution (single run)")))

    if ts is not None:
        parts.append("<h2>Path explorer</h2><p class='note'>Pick a method in the dropdown; colour = instantaneous error.</p>"
                     + div(fig_trajectory(ts, cfg["anchor_pos"], target)))
        parts.append("<h2>Error over time</h2>" + div(fig_error_time(ts, cfg))
                     + "<p class='note'>Static estimators cannot beat the grey snapshot bound on average; "
                     "the EKF can, because it also uses the motion between steps.</p>")
    parts.append("<h2>Where does the anchor layout work?</h2>" + div(fig_bound_map(cfg, ts)))

    if sweeps:
        parts.append("<h2>Sensitivity</h2>")
        for f in sweeps:
            parts.append(div(fig_sweep(pd.read_csv(f), target)))

    html = (f"<!doctype html><html lang='en'><head><meta charset='utf-8'>"
            f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
            f"<title>Localization Results</title><style>{CSS}</style></head><body><main>"
            f"<h1>Indoor localization – results</h1>"
            f"<p class='sub'>Simulation only · {folder.name} · anchors: {cfg.get('anchor_layout', '?')}</p>"
            + "".join(parts) + "</main></body></html>")
    out = folder / "dashboard.html"
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?", help="results folder")
    ap.add_argument("--demo", action="store_true", help="generate demo data with locref.py first")
    ap.add_argument("--offline", action="store_true", help="embed plotly.js instead of loading it from a CDN")
    args = ap.parse_args()
    repo = Path(__file__).resolve().parent.parent
    if args.demo:
        import demo_data
        folder = demo_data.write_demo(Path(args.folder) if args.folder else repo / "results" / "python_demo")
    elif args.folder:
        folder = Path(args.folder)
        if not folder.is_absolute():
            folder = (Path.cwd() / folder).resolve()
    else:
        cands = sorted([d for d in (repo / "results").glob("*") if d.is_dir() and
                        ((d / "evaluation_timeseries.csv").exists() or (d / "mc_errors.csv").exists())], reverse=True)
        if not cands:
            print("No results folder found; pass one or use --demo.", file=sys.stderr)
            return 1
        folder = cands[0]
    out = build(folder, args.offline)
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
