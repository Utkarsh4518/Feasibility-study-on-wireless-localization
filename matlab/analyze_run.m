function res = analyze_run(meas, cfg)
% ANALYZE_RUN  Post-process one measurement set into estimates and errors.
%
% res = analyze_run(meas, cfg)
%
% Pure function of (meas, cfg): needs neither Simulink nor ground-truth-derived
% tuning, so a saved run can be re-analysed with different filter settings.
%
% Input meas (from simulate_scenario or extract_simulink_measurements):
%   t, true_x, true_y         Nx1
%   rss, aoa, rtt             groups {val NxL, anchor 1xL, is_ble 1xL} or []
%   est_x, est_y (optional)   position estimate provided by the source (Simulink)
%   est_source                'rss_ls' | 'simulink_combined'
%
% Output res:
%   t, true_x, true_y, anchor_pos, dts, N
%   info   method registry (method_info)
%   est    struct per method key: x, y (Nx1), cov (2x2xN, NaN if unavailable)
%   err    struct per method key: Nx1 Euclidean error [m] (NaN if method off)
%   est_source
%
% Methods (keys): rss, rss_smooth, rss_kf, aoa, rtt, fusion, ekf.
%   rss        RSS-only weighted LS (or the Simulink estimate, see est_source)
%   rss_smooth moving average of rss
%   rss_kf     constant-velocity Kalman filter on rss (cfg.kf_input = 'raw') or
%              on rss_smooth (cfg.kf_input = 'smoothed')
%   aoa        bearings -> weighted LS
%   rtt        RTT ranges -> weighted nonlinear LS
%   fusion     per-step inverse-covariance fusion of rss_kf, aoa, rtt
%              (cfg.fusion_method = 'fixed' keeps the original fixed weights)
%   ekf        extended Kalman filter on the raw ranges and bearings

if ~isfield(meas, 'est_source') || isempty(meas.est_source)
    meas.est_source = 'rss_ls';
end
for f = {'rss', 'aoa', 'rtt'}
    if ~isfield(meas, f{1}), meas.(f{1}) = []; end
end

N = numel(meas.t);
A = cfg.anchor_pos;
info = method_info(meas.est_source);
tx = meas.true_x(:);
ty = meas.true_y(:);

% Per-step time increments (robust to variable-step solvers)
dts = [NaN; diff(meas.t(:))];
good = isfinite(dts) & dts > 0;
if any(good)
    fill = median(dts(good));
else
    fill = cfg.kf_dt_default;
end
dts(~good) = fill;

est = struct();
for k = 1:numel(info.keys)
    est.(info.keys{k}) = struct('x', nan(N, 1), 'y', nan(N, 1), 'cov', nan(2, 2, N));
end

hasProvided = isfield(meas, 'est_x') && ~isempty(meas.est_x);

%% RSS position, smoothing, Kalman
if cfg.enable_rss
    rx = nan(N, 1); ry = nan(N, 1); rcov = nan(2, 2, N);
    if hasProvided
        rx = meas.est_x(:); ry = meas.est_y(:);
    else
        assert(~isempty(meas.rss), 'analyze_run:data', 'cfg.enable_rss is true but meas.rss is empty.');
        for k = 1:N
            [p, C] = estimate_position_rss(A, meas.rss, meas.rss.val(k, :), cfg);
            rx(k) = p(1); ry(k) = p(2); rcov(:, :, k) = C;
        end
    end
    est.rss.x = rx; est.rss.y = ry; est.rss.cov = rcov;

    [sx, sy] = smooth_rss_positions(rx, ry, cfg.smooth_win, cfg.smooth_causal);
    est.rss_smooth.x = sx; est.rss_smooth.y = sy;

    Rseq = rcov;
    for k = 1:N
        if any(~isfinite(Rseq(:, :, k)), 'all')
            Rseq(:, :, k) = cfg.kf_R_fixed_m2 * eye(2);
        end
    end
    if strcmp(cfg.kf_input, 'raw')
        [kx, ky, kcov] = kalman_filter_cv(rx, ry, dts, cfg, Rseq);
    else
        [kx, ky, kcov] = kalman_filter_cv(sx, sy, dts, cfg, Rseq);
    end
    est.rss_kf.x = kx; est.rss_kf.y = ky; est.rss_kf.cov = kcov;
end

%% AoA (weighted least squares)
if cfg.enable_aoa
    assert(~isempty(meas.aoa), 'analyze_run:data', 'cfg.enable_aoa is true but meas.aoa is empty.');
    for k = 1:N
        [th, sg] = link_measurements(cfg, meas.aoa, 'aoa', meas.aoa.val(k, :));
        [p, C] = estimate_position_aoa_wls(A(meas.aoa.anchor, :), th, sg);
        est.aoa.x(k) = p(1); est.aoa.y(k) = p(2); est.aoa.cov(:, :, k) = C;
    end
end

%% RTT (range multilateration)
if cfg.enable_rtt
    assert(~isempty(meas.rtt), 'analyze_run:data', 'cfg.enable_rtt is true but meas.rtt is empty.');
    for k = 1:N
        [r, sg] = link_measurements(cfg, meas.rtt, 'rtt', meas.rtt.val(k, :));
        [p, C] = estimate_position_ranges(A(meas.rtt.anchor, :), r, sg);
        est.rtt.x(k) = p(1); est.rtt.y(k) = p(2); est.rtt.cov(:, :, k) = C;
    end
end

%% Fusion of the per-modality position estimates
if strcmp(cfg.fusion_method, 'fixed')
    est.fusion = fixed_fusion(est, cfg, N);
else
    parts = {};
    if cfg.enable_rss, parts{end + 1} = est.rss_kf; end
    if cfg.enable_aoa, parts{end + 1} = est.aoa; end
    if cfg.enable_rtt, parts{end + 1} = est.rtt; end
    if ~isempty(parts)
        est.fusion = fuse_inverse_covariance(parts, N);
    end
end
if strcmp(meas.est_source, 'simulink_combined') && cfg.enable_rss && ...
        (cfg.enable_aoa || cfg.enable_rtt)
    warning('localization:doubleCounting', ...
        ['The Simulink est_x/est_y already combines RSS, AoA and RTT (fminsearch objective). ' ...
         'Fusing it again with AoA/RTT double counts that information, so the "fusion" ' ...
         'result is optimistic for Simulink data. Use run_simulated_experiment for an ' ...
         'independent-estimate comparison.']);
end

%% Joint EKF on the raw links
useRssLinks = cfg.enable_rss && ~isempty(meas.rss);
if useRssLinks || (cfg.enable_aoa && ~isempty(meas.aoa)) || (cfg.enable_rtt && ~isempty(meas.rtt))
    [ex, ey, ecov] = ekf_joint(meas, cfg, dts);
    est.ekf.x = ex; est.ekf.y = ey; est.ekf.cov = ecov;
end

%% Errors: Euclidean (L2) distance per time step [m]
err = struct();
for k = 1:numel(info.keys)
    key = info.keys{k};
    err.(key) = hypot(tx - est.(key).x, ty - est.(key).y);
end

res.t = meas.t(:);
res.true_x = tx;
res.true_y = ty;
res.anchor_pos = A;
res.dts = dts;
res.N = N;
res.info = info;
res.est = est;
res.err = err;
res.est_source = meas.est_source;
end

function f = fixed_fusion(est, cfg, N)
% Original behaviour: w*KF + (1-w)*AoA, falling back to whichever modality is on.
f = struct('x', nan(N, 1), 'y', nan(N, 1), 'cov', nan(2, 2, N));
w = cfg.fusion_weight_kf;
if cfg.enable_rss && cfg.enable_aoa
    f.x = w * est.rss_kf.x + (1 - w) * est.aoa.x;
    f.y = w * est.rss_kf.y + (1 - w) * est.aoa.y;
elseif cfg.enable_rss
    f.x = est.rss_kf.x; f.y = est.rss_kf.y;
elseif cfg.enable_aoa
    f.x = est.aoa.x; f.y = est.aoa.y;
elseif cfg.enable_rtt
    f.x = est.rtt.x; f.y = est.rtt.y;
end
end
