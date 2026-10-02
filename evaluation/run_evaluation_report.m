function reportPath = run_evaluation_report(res, cfg, outDir, figs)
% RUN_EVALUATION_REPORT  Write metrics, time series, config and figures to a folder.
%
% reportPath = run_evaluation_report(res, cfg, outDir, figs)
%
% Inputs:
%   res    - result struct from analyze_run
%   cfg    - config struct used for the run
%   outDir - existing or new folder (see new_run_dir)
%   figs   - (optional) struct of figure handles from plot_results; each field
%            is exported as fig_<field>.png (300 dpi) and fig_<field>.pdf
%
% Creates in outDir:
%   metrics.csv               one row per method: mean, median, p90, max, min,
%                             std, rmse, fraction under target, sample count
%   evaluation_timeseries.csv one row per step: truth and, per method,
%                             <key>_x, <key>_y, err_<key>  (read by python/)
%   cfg.json                  full config snapshot (also loadable in python/locref.py)
%   metrics.mat               stats, res, cfg
%   report_info.mat           timestamp, seed, MATLAB version, git commit
%   fig_*.png / fig_*.pdf     figures

if nargin < 4, figs = struct(); end
if ~isfolder(outDir), mkdir(outDir); end

stats = compute_error_stats(res.err, cfg);
write_metrics_csv(stats, res.info, fullfile(outDir, 'metrics.csv'));
write_timeseries_csv(res, fullfile(outDir, 'evaluation_timeseries.csv'));
write_config_json(cfg, fullfile(outDir, 'cfg.json'));
save(fullfile(outDir, 'metrics.mat'), 'stats', 'res', 'cfg');

names = fieldnames(figs);
for i = 1:numel(names)
    export_figure(figs.(names{i}), fullfile(outDir, ['fig_' names{i}]));
end

report_info = struct();
report_info.timestamp = char(datetime('now'));
report_info.reportPath = outDir;
report_info.random_seed = cfg.random_seed;
report_info.matlab_version = version;
report_info.git_commit = git_commit();
save(fullfile(outDir, 'report_info.mat'), 'report_info');

reportPath = outDir;
fprintf('Evaluation report saved to: %s\n', outDir);
end

function write_metrics_csv(stats, info, filepath)
keys = {};
names = {};
M = [];
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(stats, key), continue; end
    s = stats.(key);
    keys{end + 1, 1} = key; %#ok<AGROW>
    names{end + 1, 1} = info.names{k}; %#ok<AGROW>
    M(end + 1, :) = [s.mean_err, s.median_err, s.p90_err, s.max_err, s.min_err, ...
        s.std_err, s.rmse_err, s.frac_under_target, s.n]; %#ok<AGROW>
end
T = table(keys, names, M(:, 1), M(:, 2), M(:, 3), M(:, 4), M(:, 5), M(:, 6), M(:, 7), ...
    M(:, 8), M(:, 9), 'VariableNames', {'method', 'name', 'mean_m', 'median_m', 'p90_m', ...
    'max_m', 'min_m', 'std_m', 'rmse_m', 'frac_under_target', 'n'});
writetable(T, filepath);
end

function write_timeseries_csv(res, filepath)
N = res.N;
T = table((1:N)', res.t(:), res.true_x(:), res.true_y(:), ...
    'VariableNames', {'index', 't', 'true_x', 'true_y'});
for k = 1:numel(res.info.keys)
    key = res.info.keys{k};
    T.([key '_x']) = res.est.(key).x(:);
    T.([key '_y']) = res.est.(key).y(:);
end
for k = 1:numel(res.info.keys)
    key = res.info.keys{k};
    T.(['err_' key]) = res.err.(key)(:);
end
writetable(T, filepath);
end

function write_config_json(cfg, filepath)
try
    txt = jsonencode(cfg, 'PrettyPrint', true);
catch
    txt = jsonencode(cfg);
end
fid = fopen(filepath, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
end

function h = git_commit()
h = '';
try
    [st, out] = system('git rev-parse --short HEAD');
    if st == 0, h = strtrim(out); end
catch
end
end
