%% RUN_EXPERIMENT  Top-level entry: run full localization pipeline.
%
% All behavior is controlled by the configuration struct. Change only the
% config to rerun experiments (or load a .mat config).
%
% Usage:
%   run_experiment()                    % use localization_config()
%   run_experiment(cfg)                 % use provided config
%   run_experiment(load_config('exp.mat'))  % rerun from saved config
%   out = run_experiment(...);
%   [out, results] = run_experiment(...);
%
% Simulation only. No real-world data or hardware.

function [out, results] = run_experiment(cfg)

repoRoot = fileparts(mfilename('fullpath'));
if isempty(repoRoot), repoRoot = pwd; end

addpath(fullfile(repoRoot, 'configs'));
addpath(fullfile(repoRoot, 'signal_models'));
addpath(fullfile(repoRoot, 'filters'));
addpath(fullfile(repoRoot, 'estimators'));
addpath(fullfile(repoRoot, 'evaluation'));
addpath(fullfile(repoRoot, 'ml'));
addpath(fullfile(repoRoot, 'LocalizationRSSandsub'));

if nargin < 1 || isempty(cfg)
    cfg = localization_config();
end

% Reproducibility: fixed random seed (MATLAB only; set [] to skip)
if isfield(cfg, 'random_seed') && ~isempty(cfg.random_seed)
    rng(cfg.random_seed);
    fprintf('Random seed set to %d for reproducibility.\n', cfg.random_seed);
end

modelName = cfg.modelName;
disp(['Running simulation for model: ', modelName]);
out = sim(modelName);

%% Extract ground truth and raw RSS-based estimates
true_x = out.true_x(:);
true_y = out.true_y(:);
est_x  = out.est_x(:);
est_y  = out.est_y(:);

N = min([length(true_x), length(true_y), length(est_x), length(est_y)]);
true_x = true_x(1:N); true_y = true_y(1:N);
est_x  = est_x(1:N);  est_y  = est_y(1:N);

T = N;
anchor_pos = cfg.anchor_pos;

%% Defaults for estimates (NaN when modality disabled or unavailable)
est_x_smooth = nan(N,1); est_y_smooth = nan(N,1);
kf_x = nan(N,1); kf_y = nan(N,1);
est_aoa_x = nan(T,1); est_aoa_y = nan(T,1);
est_rtt_x = nan(T,1); est_rtt_y = nan(T,1);
haveRTT = false;

%% Filters: RSS smoothing and Kalman (only if RSS enabled)
if cfg.enable_rss
    [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, cfg.smooth_win);
    if isfield(out, 'tout') && numel(out.tout) > 1
        dt = median(diff(out.tout));
    else
        dt = cfg.kf_dt_default;
    end
    [kf_x, kf_y] = kalman_filter_rss(est_x_smooth, est_y_smooth, dt, cfg, true_x, true_y);
else
    est_x_smooth = est_x; est_y_smooth = est_y;
end

%% Estimators: AoA WLS (only if AoA enabled)
if cfg.enable_aoa
    aoa_names = cfg.aoa_names;
    aoa_data = nan(T, numel(aoa_names));
    for i = 1:numel(aoa_names)
        sig = getSignalIfExists(out, aoa_names{i});
        if isempty(sig), continue; end
        data_i = sig.Values.Data(:);
        aoa_data(1:min(T,length(data_i)), i) = data_i(1:min(T,length(data_i)));
    end
    aoa_rad = deg2rad(aoa_data);
    for t = 1:T
        thetas = aoa_rad(t,:)';
        if any(isnan(thetas)), continue; end
        [est_aoa_x(t), est_aoa_y(t)] = estimate_position_aoa_wls(anchor_pos, thetas);
    end
end

%% Estimators: RTT trilateration (only if RTT enabled)
if cfg.enable_rtt
    rtt_names = cfg.rtt_names;
    c = cfg.speed_of_light;
    rtt_data = nan(T, numel(rtt_names));
    haveRTT = true;
    for i = 1:numel(rtt_names)
        sig = getSignalIfExists(out, rtt_names{i});
        if isempty(sig)
            haveRTT = false;
            break;
        end
        di = sig.Values.Data(:);
        rtt_data(1:min(T,numel(di)), i) = di(1:min(T,numel(di)));
    end
    if haveRTT
        rtt_distances = (rtt_data / 2) * c;
        if cfg.noise_rtt_std_s > 0
            rtt_distances = rtt_distances + cfg.noise_rtt_std_s * c/2 * randn(size(rtt_distances));
        end
        anchor_pos_all = [anchor_pos; anchor_pos];
        for t = 1:T
            d = rtt_distances(t,:)';
            if any(isnan(d)), continue; end
            [est_rtt_x(t), est_rtt_y(t)] = estimate_position_ls(d, anchor_pos_all);
        end
    end
end

%% Fusion: combine enabled modalities
[fused_x, fused_y] = compute_fusion(cfg, kf_x, kf_y, est_aoa_x, est_aoa_y, est_rtt_x, est_rtt_y, N);

%% Build results and errors
results = build_results_struct(cfg, true_x, true_y, est_x, est_y, ...
    est_x_smooth, est_y_smooth, kf_x, kf_y, est_aoa_x, est_aoa_y, ...
    est_rtt_x, est_rtt_y, fused_x, fused_y, haveRTT, N);

%% Evaluation
compute_metrics(results, cfg);
plot_results(out, cfg, results);

% Dedicated evaluation report: stats, trajectory, histograms, save to results/
if isfield(cfg, 'save_evaluation_results') && cfg.save_evaluation_results
    run_evaluation_report(results, cfg, repoRoot);
end
end

%% -------------------------------------------------------------------------
function [fused_x, fused_y] = compute_fusion(cfg, kf_x, kf_y, est_aoa_x, est_aoa_y, est_rtt_x, est_rtt_y, N)
% Fusion based on enabled modalities. Weights from config when both RSS and AoA are on.
fused_x = nan(N,1);
fused_y = nan(N,1);
use_rss = cfg.enable_rss;
use_aoa = cfg.enable_aoa;
use_rtt = cfg.enable_rtt;

if use_rss && use_aoa
    w = cfg.fusion_weight_kf;
    fused_x = w * kf_x + (1 - w) * est_aoa_x;
    fused_y = w * kf_y + (1 - w) * est_aoa_y;
elseif use_rss
    fused_x = kf_x;
    fused_y = kf_y;
elseif use_aoa
    fused_x = est_aoa_x;
    fused_y = est_aoa_y;
elseif use_rtt
    fused_x = est_rtt_x;
    fused_y = est_rtt_y;
end
end

%% -------------------------------------------------------------------------
function results = build_results_struct(cfg, true_x, true_y, est_x, est_y, ...
    est_x_smooth, est_y_smooth, kf_x, kf_y, est_aoa_x, est_aoa_y, ...
    est_rtt_x, est_rtt_y, fused_x, fused_y, haveRTT, N)
results = struct();
results.true_x = true_x;
results.true_y = true_y;
results.est_x_raw = est_x;
results.est_y_raw = est_y;
results.est_x_smooth = est_x_smooth;
results.est_y_smooth = est_y_smooth;
results.kf_x = kf_x;
results.kf_y = kf_y;
results.est_aoa_x = est_aoa_x;
results.est_aoa_y = est_aoa_y;
results.est_rtt_x = est_rtt_x;
results.est_rtt_y = est_rtt_y;
results.fused_x = fused_x;
results.fused_y = fused_y;
results.haveRTT = haveRTT;
results.enable_rss = cfg.enable_rss;
results.enable_aoa = cfg.enable_aoa;
results.enable_rtt = cfg.enable_rtt;

% Localization errors: Euclidean (L2) distance in 2D, metres, one value per timestep (instantaneous).
results.errors_smooth = hypot(true_x - est_x_smooth, true_y - est_y_smooth);
results.errors_kf     = hypot(true_x - kf_x,        true_y - kf_y);
results.errors_aoa    = hypot(true_x - est_aoa_x,   true_y - est_aoa_y);
results.errors_rtt    = hypot(true_x - est_rtt_x,   true_y - est_rtt_y);
results.errors_fused  = hypot(true_x - fused_x,    true_y - fused_y);
end
