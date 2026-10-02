"""Tests for the reference implementation. Run: pytest python/tests"""
import copy
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import locref as L  # noqa: E402


@pytest.fixture
def cfg():
    return L.default_cfg()


def test_ranges_exact_without_noise():
    A = np.array([[0, 0], [0, 5], [5, 0]], float)
    p_true = np.array([2.0, 1.5])
    r = np.hypot(*(p_true - A).T)
    p, C = L.estimate_position_ranges(A, r, np.full(3, 0.1))
    assert np.allclose(p, p_true, atol=1e-6)
    assert C.shape == (2, 2) and np.all(np.isfinite(C))


def test_ranges_accepts_duplicate_anchors():
    A = np.array([[0, 0], [0, 5], [5, 0]] * 2, float)
    p_true = np.array([3.0, 1.0])
    p, _ = L.estimate_position_ranges(A, np.hypot(*(p_true - A).T), np.full(6, 0.1))
    assert np.allclose(p, p_true, atol=1e-6)


def test_ranges_underdetermined_returns_nan():
    A = np.array([[0, 0], [0, 0]], float)
    p, C = L.estimate_position_ranges(A, np.array([1.0, 1.0]), np.array([0.1, 0.1]))
    assert np.all(np.isnan(p)) and np.all(np.isnan(C))


def test_aoa_exact_without_noise():
    A = np.array([[0, 0], [0, 5], [5, 0]], float)
    p_true = np.array([2.0, 1.5])
    th = np.arctan2(p_true[1] - A[:, 1], p_true[0] - A[:, 0])
    p, C = L.estimate_position_aoa_wls(A, th, np.full(3, 0.03))
    assert np.allclose(p, p_true, atol=1e-9)
    assert np.all(np.isfinite(C))


def test_aoa_handles_missing_bearing():
    A = np.array([[0, 0], [0, 5], [5, 0]], float)
    p_true = np.array([2.0, 1.5])
    th = np.arctan2(p_true[1] - A[:, 1], p_true[0] - A[:, 0])
    th[1] = np.nan
    p, _ = L.estimate_position_aoa_wls(A, th, np.full(3, 0.03))
    assert np.allclose(p, p_true, atol=1e-9)


def test_kalman_converges_on_line(cfg):
    N = 80
    t = np.arange(N) * 0.2
    x, y = 0.5 * t, np.full(N, 2.0)
    rng = np.random.default_rng(0)
    zx, zy = x + 0.2 * rng.standard_normal(N), y + 0.2 * rng.standard_normal(N)
    R = np.tile(0.04 * np.eye(2), (N, 1, 1))
    kx, ky, cov = L.kalman_filter_cv(zx, zy, 0.2, cfg, R)
    assert np.mean(np.hypot(kx - x, ky - y)[20:]) < np.mean(np.hypot(zx - x, zy - y)[20:])
    assert np.all(np.isfinite(cov[-1]))


def test_kalman_survives_nan_and_recovers_from_outliers(cfg):
    N = 60
    x, y = np.linspace(0, 3, N), np.full(N, 1.0)
    zx, zy = x.copy(), y.copy()
    zx[10] = np.nan
    zx[30:40] += 5.0  # sustained offset -> gate rejects, then re-initialises
    R = np.tile(0.04 * np.eye(2), (N, 1, 1))
    kx, ky, _ = L.kalman_filter_cv(zx, zy, 0.2, cfg, R)
    assert np.isfinite(kx[10])
    assert abs(kx[-1] - (x[-1] + 5.0 * 0)) < 0.5  # back on track after the offset ends


def test_fusion_handles_nan_and_improves():
    N = 3
    c1 = np.tile(np.eye(2) * 0.01, (N, 1, 1))
    c2 = np.tile(np.eye(2) * 0.04, (N, 1, 1))
    a = (np.array([1.0, np.nan, 1.0]), np.array([1.0, np.nan, 1.0]), c1)
    b = (np.array([1.2, 1.2, np.nan]), np.array([1.2, 1.2, np.nan]), c2)
    fx, fy, fc = L.fuse_inverse_covariance([a, b], N)
    assert np.isclose(fx[0], (1.0 / 0.01 + 1.2 / 0.04) / (1 / 0.01 + 1 / 0.04))
    assert fc[0][0, 0] < 0.01            # fused variance below the best input
    assert fx[1] == 1.2 and fx[2] == 1.0  # falls back to whichever is available


def test_error_stats_known_vector():
    s = L.error_stats(np.array([0.1, 0.2, 0.3, 0.4, np.nan, 1.0]), target=0.5)
    assert s["n"] == 5
    assert np.isclose(s["mean"], 0.4) and np.isclose(s["median"], 0.3)
    assert np.isclose(s["frac_under_target"], 0.8)


def test_crlb_orthogonal_ranges_matches_closed_form(cfg):
    # Agent at the origin, anchors on the axes -> unit vectors orthogonal, J = I/s^2.
    c = copy.deepcopy(cfg)
    c.update(enable_rss=False, enable_aoa=False, use_ble=False)
    c["anchor_pos"] = np.array([[3.0, 0.0], [0.0, 4.0]])
    s = L.C_LIGHT * c["channel"]["wifi"]["rtt_std_s"] / 2
    assert np.isclose(L.crlb_rmse(c, 0.0, 0.0), np.sqrt(2) * s, rtol=1e-6)


def test_crlb_rss_matches_hand_formula(cfg):
    # One RSS link: sigma_d = d*ln10/(10 n)*sigma_dB, J = u u^T / sigma_d^2 (rank 1).
    c = copy.deepcopy(cfg)
    c.update(enable_rtt=False, enable_aoa=False, use_ble=False)
    c["anchor_pos"] = np.array([[0.0, 0.0], [10.0, 0.0]])
    ch = c["channel"]["wifi"]
    px, py = 2.0, 3.0
    J = L.fisher_information(c, px, py, ("wifi",), ("wifi",))
    lam = 10 * ch["n"] / np.log(10)
    expect = np.zeros((2, 2))
    for ax in (0.0, 10.0):
        d = np.array([px - ax, py])
        expect += lam**2 / ch["rss_std_dB"] ** 2 * np.outer(d, d) / (d @ d) ** 2
    assert np.allclose(J, expect)


def test_scenario_is_reproducible_and_seed_dependent(cfg):
    a, b, c = (L.simulate_scenario(cfg, s) for s in (1, 1, 2))
    assert np.array_equal(a["rtt"]["val"], b["rtt"]["val"])
    assert not np.array_equal(a["rtt"]["val"], c["rtt"]["val"])


def test_trajectory_stays_in_bounds_and_has_expected_speed(cfg):
    t, x, y = L.make_trajectory(cfg["trajectory"])
    v = np.hypot(np.diff(x), np.diff(y)) / np.diff(t)
    assert np.all(v <= cfg["trajectory"]["speed_mps"] + 1e-9)
    assert x.min() >= 0.8 - 1e-9 and y.min() >= 0.8 - 1e-9


def test_pipeline_ordering_with_model_anchors(cfg):
    mc = L.monte_carlo(cfg, 8)
    s = mc["summary"]
    assert s["ekf"]["mean"] < s["rtt"]["mean"] < s["rss"]["mean"]
    assert s["fusion"]["mean"] < min(s["aoa"]["mean"], s["rtt"]["mean"])
    assert s["ekf"]["frac_under_target"] > 0.95


def test_wrong_anchors_are_much_worse(cfg):
    meas = L.simulate_scenario(cfg, 7)
    good = L.analyze_run(meas, cfg)
    bad_cfg = copy.deepcopy(cfg)
    bad_cfg["anchor_pos"] = np.array([[1, 3], [5, 7], [10, 11]], float)
    bad = L.analyze_run(meas, bad_cfg)
    assert np.nanmean(bad["err"]["aoa"]) > 10 * np.nanmean(good["err"]["aoa"])


def test_collinear_layout_hurts_range_methods(cfg):
    good = L.monte_carlo(cfg, 5)["summary"]["rtt"]["mean"]
    c = L.set_layout(copy.deepcopy(cfg), "collinear")
    assert L.monte_carlo(c, 5)["summary"]["rtt"]["mean"] > 3 * good


def test_zero_noise_gives_exact_geometry_estimators(cfg):
    c = copy.deepcopy(cfg)
    c["noise_scale"] = {"rss": 0, "aoa": 0, "rtt": 0}
    res = L.analyze_run(L.simulate_scenario(c, 1), c)
    for k in ("rss", "aoa", "rtt", "fusion"):
        assert np.nanmax(res["err"][k]) < 1e-4


def test_disabled_modalities_are_nan(cfg):
    c = copy.deepcopy(cfg)
    c.update(enable_aoa=False, enable_rtt=False)
    res = L.analyze_run(L.simulate_scenario(c, 1), c)
    assert np.all(np.isnan(res["err"]["aoa"])) and np.all(np.isnan(res["err"]["rtt"]))
    assert np.isfinite(res["err"]["rss"]).all()


def test_t_crit():
    assert np.isclose(L.t_crit95(9), 2.262) and L.t_crit95(1000) == 1.96
