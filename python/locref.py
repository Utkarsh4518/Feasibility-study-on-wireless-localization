"""
Reference implementation of the localization pipeline (numpy only).

Mirrors the MATLAB code in this repository (signal_models/, estimators/, filters/,
evaluation/) so the algorithms can be checked, benchmarked and plotted without
MATLAB/Simulink. Random numbers differ from MATLAB (different generators), so
results agree statistically, not sample-for-sample.

Simulation only. No real-world data.
"""

from __future__ import annotations

import copy
from typing import Dict, List, Optional, Tuple

import numpy as np

C_LIGHT = 3e8

# Methods reported by the pipeline: key -> display name
METHODS: Dict[str, str] = {
    "rss": "RSS (raw)",
    "rss_smooth": "RSS smoothed",
    "rss_kf": "RSS + Kalman",
    "aoa": "AoA WLS",
    "rtt": "RTT trilateration",
    "fusion": "Fusion (inv-cov)",
    "ekf": "EKF (joint)",
}

ANCHOR_LAYOUTS = {
    # Anchors hard-coded in Localization_Ependorfv2.slx
    "model": [[0, 0], [0, 5], [5, 0]],
    "four_corners": [[0, 0], [5, 0], [5, 5], [0, 5]],
    "triangle": [[0, 0], [5, 0], [2.5, 4.33]],
    # Poor geometry on purpose: nearly collinear anchors
    "collinear": [[0, 0], [2.5, 2.6], [5, 5]],
}


def default_cfg() -> dict:
    """Same defaults as configs/localization_config.m."""
    return {
        "random_seed": 42,
        "anchor_layout": "model",
        "anchor_pos": np.array(ANCHOR_LAYOUTS["model"], dtype=float),
        "enable_rss": True,
        "enable_aoa": True,
        "enable_rtt": True,
        "use_ble": True,          # BLE links in RSS/RTT
        "use_ble_aoa": False,     # BLE AoA (5 deg) off, as in the Simulink logging
        "channel": {
            "wifi": {"Ptx_dBm": 0.0, "PL0_dB": 30.0, "n": 2.2, "d0_m": 1.0,
                     "rss_std_dB": 1.5, "aoa_std_deg": 2.0, "rtt_std_s": 1e-9},
            "ble": {"Ptx_dBm": 0.0, "PL0_dB": 50.0, "n": 3.0, "d0_m": 1.0,
                    "rss_std_dB": 1.5, "aoa_std_deg": 5.0, "rtt_std_s": 5e-9},
        },
        "noise_scale": {"rss": 1.0, "aoa": 1.0, "rtt": 1.0},
        "trajectory": {
            "waypoints": np.array([[0.8, 0.8], [3.6, 0.8], [0.8, 3.6], [0.8, 0.8]]),
            "speed_mps": 0.5,
            "dt": 0.2,
        },
        "smooth_win": 5,
        "smooth_causal": True,
        "kf_sigma_a": 0.5,
        "kf_R_floor_m2": 0.05,
        "kf_R_fixed_m2": 1.0,     # used when the RSS estimator provides no covariance
        "kf_chi2_gate": 9.21,
        "kf_max_rejects": 5,
        "kf_P0_diag": [25, 4, 25, 4],
        "ekf_sigma_a": 0.5,
        "ekf_gate": 9.0,          # scalar innovation gate (3 sigma)
        "ekf_P0_diag": [25, 4, 25, 4],
        "fusion_method": "inverse_cov",   # 'inverse_cov' | 'fixed'
        "fusion_weight_kf": 0.7,
        "target_error_m": 0.5,
    }


def set_layout(cfg: dict, name: str) -> dict:
    cfg["anchor_layout"] = name
    cfg["anchor_pos"] = np.array(ANCHOR_LAYOUTS[name], dtype=float)
    return cfg


# --------------------------------------------------------------------------
# Scenario
# --------------------------------------------------------------------------
def make_trajectory(tcfg: dict) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    wp = np.asarray(tcfg["waypoints"], dtype=float)
    seg = np.hypot(*np.diff(wp, axis=0).T)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    step = tcfg["speed_mps"] * tcfg["dt"]
    sk = np.arange(0.0, s[-1] + 1e-9, step)
    x = np.interp(sk, s, wp[:, 0])
    y = np.interp(sk, s, wp[:, 1])
    t = np.arange(len(sk)) * tcfg["dt"]
    return t, x, y


def _links(cfg: dict, tech_list: List[str]) -> Tuple[np.ndarray, np.ndarray]:
    K = cfg["anchor_pos"].shape[0]
    anchor, is_ble = [], []
    for tech in tech_list:
        anchor += list(range(K))
        is_ble += [tech == "ble"] * K
    return np.array(anchor), np.array(is_ble, dtype=bool)


def simulate_scenario(cfg: dict, seed: Optional[int] = None) -> dict:
    """Generate RSS / AoA / RTT measurements along the trajectory."""
    rng = np.random.default_rng(cfg["random_seed"] if seed is None else seed)
    t, tx, ty = make_trajectory(cfg["trajectory"])
    A = cfg["anchor_pos"]
    K = A.shape[0]
    ns = cfg["noise_scale"]
    N = len(t)

    def make_mod(kind: str, techs: List[str]) -> dict:
        anchor, is_ble = _links(cfg, techs)
        val = np.zeros((N, len(anchor)))
        for l, (a, b) in enumerate(zip(anchor, is_ble)):
            ch = cfg["channel"]["ble" if b else "wifi"]
            dx, dy = tx - A[a, 0], ty - A[a, 1]
            d = np.maximum(np.hypot(dx, dy), ch["d0_m"])
            if kind == "rss":
                pl = ch["PL0_dB"] + 10 * ch["n"] * np.log10(d / ch["d0_m"])
                val[:, l] = ch["Ptx_dBm"] - pl + ns["rss"] * ch["rss_std_dB"] * rng.standard_normal(N)
            elif kind == "aoa":
                ang = np.arctan2(dy, dx) + np.deg2rad(ns["aoa"] * ch["aoa_std_deg"] * rng.standard_normal(N))
                val[:, l] = np.mod(np.rad2deg(ang), 360.0)
            else:
                val[:, l] = 2 * d / C_LIGHT + ns["rtt"] * ch["rtt_std_s"] * rng.standard_normal(N)
        return {"val": val, "anchor": anchor, "is_ble": is_ble}

    rr_techs = ["wifi", "ble"] if cfg["use_ble"] else ["wifi"]
    aoa_techs = ["wifi", "ble"] if cfg["use_ble_aoa"] else ["wifi"]
    return {
        "t": t, "true_x": tx, "true_y": ty,
        "rss": make_mod("rss", rr_techs),
        "aoa": make_mod("aoa", aoa_techs),
        "rtt": make_mod("rtt", rr_techs),
        "est_source": "rss_ls",
    }


# --------------------------------------------------------------------------
# Link statistics shared by estimators and error bounds
# --------------------------------------------------------------------------
def _channel(cfg, is_ble):
    return cfg["channel"]["ble" if is_ble else "wifi"]


def rss_to_range(rss, ch):
    return ch["d0_m"] * 10 ** ((ch["Ptx_dBm"] - ch["PL0_dB"] - rss) / (10 * ch["n"]))


def rss_range_sigma(d, ch, scale):
    """Std of the range derived from RSS: sigma_d = d * ln(10)/(10 n) * sigma_dB."""
    return d * np.log(10) / (10 * ch["n"]) * scale * ch["rss_std_dB"]


def rtt_range_sigma(ch, scale):
    return max(C_LIGHT * scale * ch["rtt_std_s"] / 2, 1e-3)


def aoa_sigma_rad(ch, scale):
    return max(np.deg2rad(scale * ch["aoa_std_deg"]), 1e-4)


# --------------------------------------------------------------------------
# Estimators
# --------------------------------------------------------------------------
def estimate_position_ranges(anchors, ranges, sigma, x0=None, iters=40):
    """Weighted nonlinear least squares from ranges (Levenberg-Marquardt).

    anchors: Lx2 (one row per link, duplicates allowed), ranges/sigma: L.
    Returns (pos[2], cov[2x2]); NaN when under-determined.
    """
    anchors = np.asarray(anchors, float)
    ranges = np.asarray(ranges, float)
    sigma = np.broadcast_to(np.asarray(sigma, float), ranges.shape)
    ok = np.isfinite(ranges) & np.isfinite(sigma) & (sigma > 0)
    if ok.sum() < 2 or len(np.unique(anchors[ok], axis=0)) < 2:
        return np.full(2, np.nan), np.full((2, 2), np.nan)
    a, r, w = anchors[ok], ranges[ok], 1.0 / sigma[ok] ** 2
    p = np.mean(np.unique(a, axis=0), axis=0) if x0 is None or not np.all(np.isfinite(x0)) else np.array(x0, float)

    def cost(q):
        d = np.hypot(*(q - a).T)
        return np.sum(w * (r - d) ** 2)

    lam, c0 = 1e-2, cost(p)
    for _ in range(iters):
        diff = p - a
        d = np.maximum(np.hypot(*diff.T), 1e-9)
        J = diff / d[:, None]
        H = J.T @ (w[:, None] * J)
        g = J.T @ (w * (r - d))
        try:
            step = np.linalg.solve(H + lam * np.diag(np.diag(H)) + 1e-12 * np.eye(2), g)
        except np.linalg.LinAlgError:
            break
        c1 = cost(p + step)
        if c1 < c0:
            p, c0, lam = p + step, c1, lam * 0.3
            if np.linalg.norm(step) < 1e-7:
                break
        else:
            lam *= 5
            if lam > 1e8:
                break
    diff = p - a
    d = np.maximum(np.hypot(*diff.T), 1e-9)
    J = diff / d[:, None]
    H = J.T @ (w[:, None] * J)
    cov = np.linalg.inv(H) if np.linalg.cond(H) < 1e12 else np.full((2, 2), np.nan)
    return p, cov


def estimate_position_aoa_wls(anchors, theta_rad, sigma_rad):
    """Position from bearings (anchor -> agent) by weighted least squares.

    Each bearing defines a line; the signed distance of p to line i is
    n_i.(p - a_i) with n_i = [sin th, -cos th]. A bearing error dth moves the
    line by about d_i*dth at the agent, so weights are 1/(d_i*sigma)^2, with d_i
    taken from a first unweighted pass. Returns (pos, cov).
    """
    anchors = np.asarray(anchors, float)
    th = np.asarray(theta_rad, float)
    sig = np.broadcast_to(np.asarray(sigma_rad, float), th.shape)
    ok = np.isfinite(th)
    if ok.sum() < 2:
        return np.full(2, np.nan), np.full((2, 2), np.nan)
    a, th, sig = anchors[ok], th[ok], sig[ok]
    n = np.column_stack([np.sin(th), -np.cos(th)])
    b = np.sum(n * a, axis=1)
    w = np.ones(len(th))
    p = np.full(2, np.nan)
    for _ in range(2):
        H = n.T @ (w[:, None] * n)
        if np.linalg.cond(H) > 1e12:
            return np.full(2, np.nan), np.full((2, 2), np.nan)
        p = np.linalg.solve(H, n.T @ (w * b))
        d = np.maximum(np.hypot(*(p - a).T), 0.5)
        w = 1.0 / (d * sig) ** 2
    H = n.T @ (w[:, None] * n)
    return p, np.linalg.inv(H)


def estimate_position_rss(anchors, rss, is_ble, cfg):
    """RSS -> ranges -> weighted LS. Returns (pos, cov)."""
    ranges = np.array([rss_to_range(v, _channel(cfg, b)) for v, b in zip(rss, is_ble)])
    sigma = np.array([max(rss_range_sigma(d, _channel(cfg, b), cfg["noise_scale"]["rss"]), 0.2)
                      for d, b in zip(ranges, is_ble)])
    return estimate_position_ranges(anchors, ranges, sigma)


# --------------------------------------------------------------------------
# Filters
# --------------------------------------------------------------------------
def smooth_positions(x, y, win, causal=True):
    def f(v):
        v = np.asarray(v, float)
        out = np.full_like(v, np.nan)
        for k in range(len(v)):
            lo = max(0, k - win + 1) if causal else max(0, k - win // 2)
            hi = k + 1 if causal else min(len(v), k + win // 2 + 1)
            seg = v[lo:hi]
            seg = seg[np.isfinite(seg)]
            out[k] = seg.mean() if seg.size else np.nan
        return out
    return f(x), f(y)


def step_dts(t, default_dt):
    """Per-step time increments (first entry unused); non-positive/NaN steps -> median."""
    t = np.asarray(t, float)
    dts = np.concatenate([[np.nan], np.diff(t)])
    good = dts[np.isfinite(dts) & (dts > 0)]
    fill = np.median(good) if good.size else default_dt
    dts[~(np.isfinite(dts) & (dts > 0))] = fill
    return dts


def _cv_matrices(dt, sigma_a):
    A = np.array([[1, dt, 0, 0], [0, 1, 0, 0], [0, 0, 1, dt], [0, 0, 0, 1]], float)
    q = sigma_a ** 2
    Q = q * np.array([[dt**4 / 4, dt**3 / 2, 0, 0], [dt**3 / 2, dt**2, 0, 0],
                      [0, 0, dt**4 / 4, dt**3 / 2], [0, 0, dt**3 / 2, dt**2]])
    return A, Q


def kalman_filter_cv(zx, zy, dt, cfg, R_seq):
    """Constant-velocity Kalman filter on position measurements.

    R_seq: Nx2x2 measurement covariance per step (never derived from ground truth).
    Mahalanobis gating; after kf_max_rejects consecutive rejections the filter is
    re-initialised on the current measurement (prevents permanent loss of track).
    Returns (x, y, cov[N,2,2]).
    """
    N = len(zx)
    dts = np.broadcast_to(np.asarray(dt, float), (N,))
    H = np.array([[1, 0, 0, 0], [0, 0, 1, 0]], float)
    P0 = np.diag(cfg["kf_P0_diag"]).astype(float)
    kx, ky, cov = np.full(N, np.nan), np.full(N, np.nan), np.full((N, 2, 2), np.nan)
    x, P, started, rejects = None, None, False, 0
    for k in range(N):
        z = np.array([zx[k], zy[k]])
        have = np.all(np.isfinite(z))
        if not started:
            if not have:
                continue
            x, P, started = np.array([z[0], 0, z[1], 0.0]), P0.copy(), True
        else:
            A, Q = _cv_matrices(dts[k], cfg["kf_sigma_a"])
            x, P = A @ x, A @ P @ A.T + Q
            if have:
                R = R_seq[k] + cfg["kf_R_floor_m2"] * np.eye(2)
                y_in = z - H @ x
                S = H @ P @ H.T + R
                if y_in @ np.linalg.solve(S, y_in) <= cfg["kf_chi2_gate"]:
                    K = P @ H.T @ np.linalg.inv(S)
                    I_KH = np.eye(4) - K @ H
                    x, P = x + K @ y_in, I_KH @ P @ I_KH.T + K @ R @ K.T
                    rejects = 0
                else:
                    rejects += 1
                    if rejects >= cfg["kf_max_rejects"]:
                        x, P, rejects = np.array([z[0], 0, z[1], 0.0]), P0.copy(), 0
        kx[k], ky[k] = x[0], x[2]
        cov[k] = P[np.ix_([0, 2], [0, 2])]
    return kx, ky, cov


def ekf_joint(meas, cfg, dt):
    """Extended Kalman filter fed with raw RSS/RTT ranges and AoA bearings.

    State [x, vx, y, vy]. Measurements are processed as scalars per step with a
    per-measurement innovation gate. Returns (x, y, cov[N,2,2]).
    """
    A_pos = cfg["anchor_pos"]
    N = len(meas["t"])
    ns = cfg["noise_scale"]
    dts = np.broadcast_to(np.asarray(dt, float), (N,))
    P0 = np.diag(cfg["ekf_P0_diag"]).astype(float)

    # initial position: RTT ranges if available, else anchor centroid
    x0 = np.array([np.mean(A_pos[:, 0]), np.mean(A_pos[:, 1])])
    if cfg["enable_rtt"] and meas.get("rtt") is not None:
        m = meas["rtt"]
        r = m["val"][0] * C_LIGHT / 2
        sg = [rtt_range_sigma(_channel(cfg, b), ns["rtt"]) for b in m["is_ble"]]
        p, _ = estimate_position_ranges(A_pos[m["anchor"]], r, sg)
        if np.all(np.isfinite(p)):
            x0 = p
    x = np.array([x0[0], 0, x0[1], 0.0])
    P = P0.copy()
    ex, ey, cov = np.full(N, np.nan), np.full(N, np.nan), np.full((N, 2, 2), np.nan)

    def scalar_update(x, P, innov, Hrow, var, gate):
        S = Hrow @ P @ Hrow + var
        if innov * innov / S > gate:
            return x, P
        K = P @ Hrow / S
        x = x + K * innov
        I_KH = np.eye(4) - np.outer(K, Hrow)
        return x, I_KH @ P @ I_KH.T + var * np.outer(K, K)

    for k in range(N):
        if k > 0:
            Af, Q = _cv_matrices(dts[k], cfg["ekf_sigma_a"])
            x, P = Af @ x, Af @ P @ Af.T + Q
        # ranges: RTT and RSS
        for kind in ("rtt", "rss"):
            if not cfg["enable_" + kind] or meas.get(kind) is None:
                continue
            m = meas[kind]
            for l in range(m["val"].shape[1]):
                v = m["val"][k, l]
                if not np.isfinite(v):
                    continue
                ch = _channel(cfg, m["is_ble"][l])
                a = A_pos[m["anchor"][l]]
                if kind == "rtt":
                    r, sg = v * C_LIGHT / 2, rtt_range_sigma(ch, ns["rtt"])
                else:
                    r = rss_to_range(v, ch)
                    sg = max(rss_range_sigma(r, ch, ns["rss"]), 0.2)
                dx, dy = x[0] - a[0], x[2] - a[1]
                d = max(np.hypot(dx, dy), 1e-6)
                Hrow = np.array([dx / d, 0, dy / d, 0.0])
                x, P = scalar_update(x, P, r - d, Hrow, sg**2, cfg["ekf_gate"])
        # bearings
        if cfg["enable_aoa"] and meas.get("aoa") is not None:
            m = meas["aoa"]
            for l in range(m["val"].shape[1]):
                v = m["val"][k, l]
                if not np.isfinite(v):
                    continue
                ch = _channel(cfg, m["is_ble"][l])
                a = A_pos[m["anchor"][l]]
                dx, dy = x[0] - a[0], x[2] - a[1]
                r2 = max(dx * dx + dy * dy, 1e-6)
                innov = np.angle(np.exp(1j * (np.deg2rad(v) - np.arctan2(dy, dx))))
                Hrow = np.array([-dy / r2, 0, dx / r2, 0.0])
                x, P = scalar_update(x, P, innov, Hrow, aoa_sigma_rad(ch, ns["aoa"]) ** 2, cfg["ekf_gate"])
        ex[k], ey[k] = x[0], x[2]
        cov[k] = P[np.ix_([0, 2], [0, 2])]
    return ex, ey, cov


def fuse_inverse_covariance(estimates: List[Tuple[np.ndarray, np.ndarray, np.ndarray]], N: int):
    """Per-step inverse-covariance weighted fusion of independent position estimates."""
    fx, fy, fcov = np.full(N, np.nan), np.full(N, np.nan), np.full((N, 2, 2), np.nan)
    for k in range(N):
        info, vec, used = np.zeros((2, 2)), np.zeros(2), 0
        for ex, ey, cv in estimates:
            p, Cv = np.array([ex[k], ey[k]]), cv[k]
            if not (np.all(np.isfinite(p)) and np.all(np.isfinite(Cv))) or np.linalg.cond(Cv) > 1e10:
                continue
            Ci = np.linalg.inv(Cv)
            info, vec, used = info + Ci, vec + Ci @ p, used + 1
        if used:
            Cf = np.linalg.inv(info)
            fx[k], fy[k] = Cf @ vec
            fcov[k] = Cf
    return fx, fy, fcov


# --------------------------------------------------------------------------
# Error bounds
# --------------------------------------------------------------------------
def fisher_information(cfg: dict, px: float, py: float, techs_rr=("wifi", "ble"), techs_aoa=("wifi",)) -> np.ndarray:
    """2x2 Fisher information at (px, py) from all enabled links.

    Range links (RTT, and RSS where sigma_d = d*ln10/(10n)*sigma_dB): (1/s^2) u u^T.
    Bearing links: (1/(r*sigma_theta)^2) v v^T with v perpendicular to u.
    """
    A = cfg["anchor_pos"]
    ns = cfg["noise_scale"]
    J = np.zeros((2, 2))
    for ai in range(A.shape[0]):
        dx, dy = px - A[ai, 0], py - A[ai, 1]
        d = max(np.hypot(dx, dy), 1e-6)
        u = np.array([dx, dy]) / d
        v = np.array([-u[1], u[0]])
        for tech in techs_rr:
            ch = cfg["channel"][tech]
            if cfg["enable_rtt"]:
                J += np.outer(u, u) / rtt_range_sigma(ch, ns["rtt"]) ** 2
            if cfg["enable_rss"]:
                J += np.outer(u, u) / max(rss_range_sigma(d, ch, ns["rss"]), 1e-9) ** 2
        if cfg["enable_aoa"]:
            for tech in techs_aoa:
                ch = cfg["channel"][tech]
                J += np.outer(v, v) / (d * aoa_sigma_rad(ch, ns["aoa"])) ** 2
    return J


def crlb_rmse(cfg: dict, px: float, py: float) -> float:
    """sqrt(trace(J^-1)): lower bound on 2D RMSE of an unbiased estimator."""
    techs_rr = ("wifi", "ble") if cfg["use_ble"] else ("wifi",)
    techs_aoa = ("wifi", "ble") if cfg["use_ble_aoa"] else ("wifi",)
    J = fisher_information(cfg, px, py, techs_rr, techs_aoa)
    if np.linalg.cond(J) > 1e12:
        return np.nan
    return float(np.sqrt(np.trace(np.linalg.inv(J))))


def crlb_over_time(cfg, tx, ty):
    return np.array([crlb_rmse(cfg, x, y) for x, y in zip(tx, ty)])


def crlb_map(cfg, xs, ys):
    return np.array([[crlb_rmse(cfg, x, y) for x in xs] for y in ys])


# --------------------------------------------------------------------------
# Pipeline
# --------------------------------------------------------------------------
def analyze_run(meas: dict, cfg: dict) -> dict:
    N = len(meas["t"])
    A = cfg["anchor_pos"]
    ns = cfg["noise_scale"]
    dt = step_dts(meas["t"], cfg["trajectory"]["dt"])
    nan1 = lambda: np.full(N, np.nan)
    est = {k: {"x": nan1(), "y": nan1(), "cov": np.full((N, 2, 2), np.nan)} for k in METHODS}

    # RSS-only position (simulated measurements) or model-provided estimate
    if cfg["enable_rss"]:
        m = meas["rss"]
        rx, ry = nan1(), nan1()
        rcov = np.full((N, 2, 2), np.nan)
        if "est_x" in meas:
            rx, ry = np.asarray(meas["est_x"], float), np.asarray(meas["est_y"], float)
        else:
            for k in range(N):
                p, Cv = estimate_position_rss(A[m["anchor"]], m["val"][k], m["is_ble"], cfg)
                rx[k], ry[k], rcov[k] = p[0], p[1], Cv
        est["rss"].update(x=rx, y=ry, cov=rcov)
        sx, sy = smooth_positions(rx, ry, cfg["smooth_win"], cfg["smooth_causal"])
        est["rss_smooth"].update(x=sx, y=sy)
        R_seq = rcov.copy()
        for k in range(N):
            if not np.all(np.isfinite(R_seq[k])):
                R_seq[k] = np.eye(2) * cfg["kf_R_fixed_m2"]
        kx, ky, kcov = kalman_filter_cv(sx, sy, dt, cfg, R_seq)
        est["rss_kf"].update(x=kx, y=ky, cov=kcov)

    if cfg["enable_aoa"]:
        m = meas["aoa"]
        sg = np.array([aoa_sigma_rad(_channel(cfg, b), ns["aoa"]) for b in m["is_ble"]])
        for k in range(N):
            p, Cv = estimate_position_aoa_wls(A[m["anchor"]], np.deg2rad(m["val"][k]), sg)
            est["aoa"]["x"][k], est["aoa"]["y"][k], est["aoa"]["cov"][k] = p[0], p[1], Cv

    if cfg["enable_rtt"]:
        m = meas["rtt"]
        sg = np.array([rtt_range_sigma(_channel(cfg, b), ns["rtt"]) for b in m["is_ble"]])
        for k in range(N):
            p, Cv = estimate_position_ranges(A[m["anchor"]], m["val"][k] * C_LIGHT / 2, sg)
            est["rtt"]["x"][k], est["rtt"]["y"][k], est["rtt"]["cov"][k] = p[0], p[1], Cv

    # Fusion of independent per-modality estimates
    if cfg["fusion_method"] == "fixed":
        w = cfg["fusion_weight_kf"]
        if cfg["enable_rss"] and cfg["enable_aoa"]:
            est["fusion"]["x"] = w * est["rss_kf"]["x"] + (1 - w) * est["aoa"]["x"]
            est["fusion"]["y"] = w * est["rss_kf"]["y"] + (1 - w) * est["aoa"]["y"]
        else:
            for src in ("rss_kf", "aoa", "rtt"):
                en = {"rss_kf": "enable_rss", "aoa": "enable_aoa", "rtt": "enable_rtt"}[src]
                if cfg[en]:
                    est["fusion"]["x"], est["fusion"]["y"] = est[src]["x"].copy(), est[src]["y"].copy()
                    break
    else:
        parts = []
        if cfg["enable_rss"]:
            parts.append((est["rss_kf"]["x"], est["rss_kf"]["y"], est["rss_kf"]["cov"]))
        if cfg["enable_aoa"]:
            parts.append((est["aoa"]["x"], est["aoa"]["y"], est["aoa"]["cov"]))
        if cfg["enable_rtt"]:
            parts.append((est["rtt"]["x"], est["rtt"]["y"], est["rtt"]["cov"]))
        if parts:
            fx, fy, fc = fuse_inverse_covariance(parts, N)
            est["fusion"].update(x=fx, y=fy, cov=fc)

    if cfg["enable_rss"] or cfg["enable_aoa"] or cfg["enable_rtt"]:
        ex, ey, ec = ekf_joint(meas, cfg, dt)
        est["ekf"].update(x=ex, y=ey, cov=ec)

    err = {k: np.hypot(meas["true_x"] - v["x"], meas["true_y"] - v["y"]) for k, v in est.items()}
    return {"est": est, "err": err, "dt": dt, "N": N}


def error_stats(e: np.ndarray, target: float = 0.5) -> dict:
    e = np.asarray(e, float)
    e = e[np.isfinite(e)]
    if e.size == 0:
        return {k: np.nan for k in ("mean", "median", "p90", "max", "rmse", "std", "frac_under_target", "n")}
    return {"mean": e.mean(), "median": np.median(e), "p90": np.percentile(e, 90), "max": e.max(),
            "rmse": float(np.sqrt(np.mean(e**2))), "std": e.std(ddof=1) if e.size > 1 else 0.0,
            "frac_under_target": float(np.mean(e <= target)), "n": int(e.size)}


# two-sided 95% Student-t critical values for dof = 1..30 (no scipy dependency)
_T95 = [12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179, 2.160,
        2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086, 2.080, 2.074, 2.069, 2.064, 2.060, 2.056,
        2.052, 2.048, 2.045, 2.042]


def t_crit95(dof: int) -> float:
    if dof < 1:
        return np.nan
    return _T95[dof - 1] if dof <= 30 else 1.96


def monte_carlo(cfg: dict, n_runs: int, seed0: Optional[int] = None) -> dict:
    """Run n_runs independent noise realisations. Returns pooled errors + CI of per-run mean."""
    seed0 = cfg["random_seed"] if seed0 is None else seed0
    per_run = {k: [] for k in METHODS}
    pooled = {k: [] for k in METHODS}
    for r in range(n_runs):
        meas = simulate_scenario(cfg, seed0 + r)
        res = analyze_run(meas, cfg)
        for k in METHODS:
            e = res["err"][k]
            per_run[k].append(np.nanmean(e) if np.isfinite(e).any() else np.nan)
            pooled[k].append(e)
    out = {"per_run_mean": {k: np.array(v) for k, v in per_run.items()},
           "errors": {k: np.array(v) for k, v in pooled.items()}, "n_runs": n_runs}
    summ = {}
    for k in METHODS:
        pm = out["per_run_mean"][k]
        pm = pm[np.isfinite(pm)]
        allerr = out["errors"][k].ravel()
        s = error_stats(allerr, cfg["target_error_m"])
        if pm.size > 1:
            s["mean_ci95"] = t_crit95(pm.size - 1) * pm.std(ddof=1) / np.sqrt(pm.size)
        else:
            s["mean_ci95"] = np.nan
        summ[k] = s
    out["summary"] = summ
    return out


def _set_path(cfg: dict, path: str, value):
    cur = cfg
    parts = path.split(".")
    for p in parts[:-1]:
        cur = cur[p]
    cur[parts[-1]] = value


def sweep(cfg: dict, path: str, values, n_runs: int = 20) -> List[dict]:
    """Monte Carlo at each value of a (dotted) config parameter."""
    rows = []
    for v in values:
        c = copy.deepcopy(cfg)
        if path == "anchor_layout":
            set_layout(c, v)
        else:
            _set_path(c, path, v)
        mc = monte_carlo(c, n_runs)
        for k, s in mc["summary"].items():
            rows.append({"param": path, "value": v, "method": k, **s})
    return rows
