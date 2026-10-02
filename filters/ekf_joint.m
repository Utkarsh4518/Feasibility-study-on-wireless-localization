function [ex, ey, cov] = ekf_joint(meas, cfg, dts)
% EKF_JOINT  Extended Kalman filter fed with raw ranges and bearings.
%
% [ex, ey, cov] = ekf_joint(meas, cfg, dts)
%
% Inputs:
%   meas - measurement struct (t, rss/aoa/rtt groups; see simulate_scenario).
%          A group that is empty ([]) is skipped.
%   cfg  - config struct (enable_*, ekf_sigma_a, ekf_gate, ekf_P0_diag)
%   dts  - Nx1 time step before each sample [s] (dts(1) unused)
%
% Outputs:
%   ex, ey - Nx1 position estimate [m]
%   cov    - 2x2xN position covariance
%
% State [x; vx; y; vy], constant-velocity motion. Every RTT range, RSS range
% and AoA bearing is processed as a scalar measurement with its own variance
% (link_measurements) and an innovation gate (cfg.ekf_gate on innov^2/S), so a
% single bad link is rejected without discarding the rest. Bearing innovations
% are wrapped to [-pi, pi]. Unlike fusing finished position estimates, this
% uses the raw geometry of every link directly.
%
% Initial position: RTT multilateration at the first step (or the anchor
% centroid if RTT is unavailable).

A_pos = cfg.anchor_pos;
N = numel(meas.t);
dts = dts(:);

x0 = mean(A_pos, 1);
if cfg.enable_rtt && ~isempty(meas.rtt)
    [r, s] = link_measurements(cfg, meas.rtt, 'rtt', meas.rtt.val(1, :));
    p = estimate_position_ranges(A_pos(meas.rtt.anchor, :), r, s);
    if all(isfinite(p)), x0 = p; end
end
x = [x0(1); 0; x0(2); 0];
P = diag(cfg.ekf_P0_diag(:));

ex = nan(N, 1);
ey = nan(N, 1);
cov = nan(2, 2, N);

rangeKinds = {};
if cfg.enable_rtt && ~isempty(meas.rtt), rangeKinds{end + 1} = 'rtt'; end
if cfg.enable_rss && ~isempty(meas.rss), rangeKinds{end + 1} = 'rss'; end
useAoa = cfg.enable_aoa && ~isempty(meas.aoa);

for k = 1:N
    if k > 1
        [A, Q] = cv_matrices(dts(k), cfg.ekf_sigma_a);
        x = A * x;
        P = A * P * A' + Q;
    end

    % --- range measurements (RTT, RSS)
    for ik = 1:numel(rangeKinds)
        kind = rangeKinds{ik};
        m = meas.(kind);
        [rv, sv] = link_measurements(cfg, m, kind, m.val(k, :));
        for l = 1:numel(rv)
            if ~isfinite(rv(l)), continue; end
            a = A_pos(m.anchor(l), :);
            dx = x(1) - a(1);
            dy = x(3) - a(2);
            d = max(hypot(dx, dy), 1e-6);
            Hrow = [dx / d, 0, dy / d, 0];
            [x, P] = scalar_update(x, P, rv(l) - d, Hrow, sv(l) ^ 2, cfg.ekf_gate);
        end
    end

    % --- bearing measurements (AoA)
    if useAoa
        m = meas.aoa;
        [bv, sv] = link_measurements(cfg, m, 'aoa', m.val(k, :));
        for l = 1:numel(bv)
            if ~isfinite(bv(l)), continue; end
            a = A_pos(m.anchor(l), :);
            dx = x(1) - a(1);
            dy = x(3) - a(2);
            r2 = max(dx ^ 2 + dy ^ 2, 1e-6);
            dtheta = bv(l) - atan2(dy, dx);
            innov = atan2(sin(dtheta), cos(dtheta));
            Hrow = [-dy / r2, 0, dx / r2, 0];
            [x, P] = scalar_update(x, P, innov, Hrow, sv(l) ^ 2, cfg.ekf_gate);
        end
    end

    ex(k) = x(1);
    ey(k) = x(3);
    cov(:, :, k) = P([1 3], [1 3]);
end
end

function [x, P] = scalar_update(x, P, innov, Hrow, var_, gate)
S = Hrow * P * Hrow' + var_;
if innov ^ 2 / S > gate
    return;                                  % gated out
end
K = P * Hrow' / S;
x = x + K * innov;
IKH = eye(4) - K * Hrow;
P = IKH * P * IKH' + var_ * (K * K');       % Joseph form
end
