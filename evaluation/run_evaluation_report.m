function reportPath = run_evaluation_report(results, cfg, repoRoot)
% RUN_EVALUATION_REPORT  Dedicated evaluation: stats, trajectory, histograms, save to results/.
%
% reportPath = run_evaluation_report(results, cfg, repoRoot)
%
% Inputs:
%   results  - Struct from run_experiment (true_x/y, estimates, errors_*)
%   cfg      - Config struct (enable flags, anchor positions)
%   repoRoot - Root folder of the repo (results/ created here). If empty, use pwd.
%
% Output:
%   reportPath - Path to the timestamped results folder (e.g. results/20250209_143022)
%
% Creates:
%   - results/<timestamp>/metrics.mat, metrics.csv (mean, median, max, std per method)
%   - results/<timestamp>/metrics_summary.csv (summary table: RSS-only, AoA, RTT, Kalman, Fused)
%   - results/<timestamp>/trajectory.png, trajectory.fig
%   - results/<timestamp>/error_histograms.png, error_histograms.fig
%   - results/<timestamp>/report_info.mat (timestamp, config snapshot for reproducibility)

if nargin < 3 || isempty(repoRoot)
    repoRoot = pwd;
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
reportPath = fullfile(repoRoot, 'results', timestamp);
if ~isfolder(reportPath)
    mkdir(reportPath);
end

%% 1) Compute error statistics (mean, median, max, std)
stats = compute_error_stats(results, cfg);

%% 2) Save metrics
metricsPath = fullfile(reportPath, 'metrics.mat');
save(metricsPath, 'stats', 'results', 'cfg');
write_metrics_csv(stats, fullfile(reportPath, 'metrics.csv'));
write_metrics_summary_csv(stats, fullfile(reportPath, 'metrics_summary.csv'));
% Timeseries CSV for Python (no .mat dependency)
write_timeseries_csv(results, fullfile(reportPath, 'evaluation_timeseries.csv'));

%% 3) Trajectory plot
figTraj = figure('Visible', 'off', 'Name', 'Evaluation Trajectory');
plot_trajectory(results, cfg, figTraj);
saveas(figTraj, fullfile(reportPath, 'trajectory.png'));
savefig(figTraj, fullfile(reportPath, 'trajectory.fig'));
close(figTraj);

%% 4) Error histograms
figHist = figure('Visible', 'off', 'Name', 'Error Histograms');
plot_error_histograms(results, cfg, figHist);
saveas(figHist, fullfile(reportPath, 'error_histograms.png'));
savefig(figHist, fullfile(reportPath, 'error_histograms.fig'));
close(figHist);

%% 5) Reproducibility info
report_info = struct();
report_info.timestamp = timestamp;
report_info.reportPath = reportPath;
if isfield(cfg, 'random_seed')
    report_info.random_seed = cfg.random_seed;
else
    report_info.random_seed = [];
end
save(fullfile(reportPath, 'report_info.mat'), 'report_info');

fprintf('Evaluation report saved to: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function write_metrics_summary_csv(stats, filepath)
% Write metrics_summary.csv: one row per method with display name and mean/median/max/std.
% Order: RSS-only, AoA-based, RTT-based, Kalman-filtered, Fused. Only includes methods present in stats.
% Uses existing signals only (no new methods).
method_order = {'smooth_rss', 'aoa_wls', 'rtt', 'kalman_rss', 'fusion'};
display_names = {'RSS-only', 'AoA-based', 'RTT-based', 'Kalman-filtered', 'Fused'};
method_var = {};
mean_m = [];
median_m = [];
max_m = [];
std_m = [];
for k = 1:numel(method_order)
    m = method_order{k};
    if isfield(stats, m)
        s = stats.(m);
        method_var{end+1} = display_names{k};
        mean_m(end+1) = s.mean_err;
        median_m(end+1) = s.median_err;
        max_m(end+1) = s.max_err;
        std_m(end+1) = s.std_err;
    end
end
if isempty(method_var)
    method_var = {''}; mean_m = NaN; median_m = NaN; max_m = NaN; std_m = NaN;
end
t = table(method_var', mean_m(:), median_m(:), max_m(:), std_m(:), ...
    'VariableNames', {'Method', 'Mean_error_m', 'Median_error_m', 'Max_error_m', 'Std_error_m'});
writetable(t, filepath);
end

%% -------------------------------------------------------------------------
function write_metrics_csv(stats, filepath)
methods = fieldnames(stats);
mean_m = zeros(numel(methods), 1);
median_m = zeros(numel(methods), 1);
max_m = zeros(numel(methods), 1);
min_m = zeros(numel(methods), 1);
std_m = zeros(numel(methods), 1);
for k = 1:numel(methods)
    s = stats.(methods{k});
    mean_m(k) = s.mean_err;
    median_m(k) = s.median_err;
    max_m(k) = s.max_err;
    min_m(k) = s.min_err;
    std_m(k) = s.std_err;
end
t = table(methods, mean_m, median_m, max_m, min_m, std_m, ...
    'VariableNames', {'method', 'mean_m', 'median_m', 'max_m', 'min_m', 'std_m'});
writetable(t, filepath);
end

%% -------------------------------------------------------------------------
function write_timeseries_csv(results, filepath)
% One row per timestep; allows Python to recompute metrics and plots without .mat.
% Columns err_smooth, err_kf, err_aoa, err_rtt, err_fused: instantaneous Euclidean (L2)
% error in metres (one value per row). metrics.csv holds aggregates (mean/median/max/min/std over time).
N = numel(results.true_x);
idx = (1:N)';
t = table(idx, results.true_x, results.true_y, ...
    results.est_x_smooth, results.est_y_smooth, ...
    results.kf_x, results.kf_y, ...
    results.est_aoa_x, results.est_aoa_y, ...
    results.est_rtt_x, results.est_rtt_y, ...
    results.fused_x, results.fused_y, ...
    results.errors_smooth, results.errors_kf, results.errors_aoa, ...
    results.errors_rtt, results.errors_fused, ...
    'VariableNames', {'index', 'true_x', 'true_y', ...
    'est_x_smooth', 'est_y_smooth', 'kf_x', 'kf_y', ...
    'est_aoa_x', 'est_aoa_y', 'est_rtt_x', 'est_rtt_y', ...
    'fused_x', 'fused_y', ...
    'err_smooth', 'err_kf', 'err_aoa', 'err_rtt', 'err_fused'});
writetable(t, filepath);
end

%% -------------------------------------------------------------------------
function plot_trajectory(results, cfg, fig)
figure(fig);
R = results;
hold on;
plot(R.true_x, R.true_y, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Ground truth');
if cfg.enable_rss
    plot(R.kf_x, R.kf_y, 'g--', 'DisplayName', 'RSS Kalman');
end
if cfg.enable_aoa && any(~isnan(R.est_aoa_x))
    plot(R.est_aoa_x, R.est_aoa_y, 'r--', 'DisplayName', 'AoA WLS');
end
if cfg.enable_rtt && R.haveRTT && any(~isnan(R.est_rtt_x))
    plot(R.est_rtt_x, R.est_rtt_y, 'b--', 'DisplayName', 'RTT');
end
if any(~isnan(R.fused_x))
    plot(R.fused_x, R.fused_y, 'm-', 'LineWidth', 1.2, 'DisplayName', 'Fusion');
end
plot(cfg.anchor_x, cfg.anchor_y, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'DisplayName', 'Anchors');
legend('Location', 'best');
xlabel('x (m)'); ylabel('y (m)');
title('Trajectory (evaluation report)');
grid on; axis equal;
end

%% -------------------------------------------------------------------------
function plot_error_histograms(results, cfg, fig)
figure(fig);
R = results;
labels = {};
errs = {};
if cfg.enable_rss
    labels{end+1} = 'RSS Kalman';     errs{end+1} = R.errors_kf;
    labels{end+1} = 'RSS Smoothed';  errs{end+1} = R.errors_smooth;
end
if cfg.enable_aoa
    labels{end+1} = 'AoA WLS';       errs{end+1} = R.errors_aoa;
end
if cfg.enable_rtt && R.haveRTT
    labels{end+1} = 'RTT';           errs{end+1} = R.errors_rtt;
end
labels{end+1} = 'Fusion';
errs{end+1} = R.errors_fused;

n = numel(labels);
for k = 1:n
    subplot(2, ceil(n/2), k);
    e = errs{k}(:);
    e = e(isfinite(e));
    if isempty(e)
        text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
        axis([0 1 0 1]);
    else
        histogram(e, 20, 'FaceAlpha', 0.7);
        xlabel('Error (m)');
        ylabel('Count');
        title(labels{k});
        grid on;
    end
end
sgtitle('Localization error histograms (evaluation report)');
end
