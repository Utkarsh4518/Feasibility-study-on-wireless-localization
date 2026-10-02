function mc = run_monte_carlo(cfg, nRuns, varargin)
% RUN_MONTE_CARLO  Repeat the simulated experiment over many noise realisations.
%
% mc = run_monte_carlo(cfg, nRuns)
% mc = run_monte_carlo(cfg, nRuns, 'OutDir', folder, 'Seed0', 1, 'Show', true)
%
% A single run is one noise sample, so differences between methods can be luck.
% This runs nRuns independent realisations (seeds Seed0 ... Seed0+nRuns-1;
% default Seed0 = cfg.random_seed) and reports pooled error statistics plus a
% 95% confidence interval of the mean error (Student-t over per-run means).
%
% Output mc:
%   n_runs, t           number of runs, time vector of one run
%   errors              struct: method key -> nRuns x N error matrix [m]
%   per_run_mean        struct: method key -> nRuns x 1 mean error per run
%   summary             struct: method key -> compute_error_stats fields plus
%                       mean_ci95 (half-width of the 95% CI of the mean)
%   cfg, info
%
% With 'OutDir' it writes mc_summary.csv, mc_errors.csv (long format: run,
% step, t, method, err_m), cfg.json, fig_mc_cdf and fig_mc_box (png + pdf).

p = inputParser;
addParameter(p, 'OutDir', '');
addParameter(p, 'Seed0', []);
addParameter(p, 'Show', false);
addParameter(p, 'Verbose', true);
parse(p, varargin{:});

setup_paths();
cfg = validate_config(cfg);
seed0 = p.Results.Seed0;
if isempty(seed0)
    seed0 = cfg.random_seed;
    if isempty(seed0), seed0 = 0; end
end

info = method_info('rss_ls');
errs = struct();
perRun = struct();
tvec = [];
for r = 1:nRuns
    meas = simulate_scenario(cfg, seed0 + r - 1);
    res = analyze_run(meas, cfg);
    tvec = res.t;
    for k = 1:numel(info.keys)
        key = info.keys{k};
        e = res.err.(key)(:)';
        if r == 1
            errs.(key) = nan(nRuns, numel(e));
            perRun.(key) = nan(nRuns, 1);
        end
        errs.(key)(r, :) = e;
        if any(isfinite(e))
            perRun.(key)(r) = mean(e(isfinite(e)));
        end
    end
    if p.Results.Verbose && (r == 1 || mod(r, 10) == 0 || r == nRuns)
        fprintf('Monte Carlo: %d / %d runs\n', r, nRuns);
    end
end

summary = compute_error_stats(errs, cfg);
keys = fieldnames(summary);
for i = 1:numel(keys)
    pr = perRun.(keys{i});
    pr = pr(isfinite(pr));
    if numel(pr) > 1
        summary.(keys{i}).mean_ci95 = t_crit95(numel(pr) - 1) * std(pr) / sqrt(numel(pr));
    else
        summary.(keys{i}).mean_ci95 = NaN;
    end
end

mc.n_runs = nRuns;
mc.t = tvec;
mc.errors = errs;
mc.per_run_mean = perRun;
mc.summary = summary;
mc.cfg = cfg;
mc.info = info;

if p.Results.Verbose
    print_summary(mc);
end

if ~isempty(p.Results.OutDir) || p.Results.Show
    vis = 'off';
    if p.Results.Show, vis = 'on'; end
    f1 = plot_error_cdf(errs, cfg, info, 'Visible', vis, ...
        'Title', sprintf('Position error distribution (%d Monte Carlo runs)', nRuns));
    f2 = plot_error_box(errs, cfg, info, 'Visible', vis, ...
        'Title', sprintf('Position error per method (%d Monte Carlo runs)', nRuns));
    if ~isempty(p.Results.OutDir)
        outDir = p.Results.OutDir;
        if ~isfolder(outDir), mkdir(outDir); end
        write_summary_csv(mc, fullfile(outDir, 'mc_summary.csv'));
        write_errors_csv(mc, fullfile(outDir, 'mc_errors.csv'));
        write_json(cfg, fullfile(outDir, 'cfg.json'));
        export_figure(f1, fullfile(outDir, 'fig_mc_cdf'));
        export_figure(f2, fullfile(outDir, 'fig_mc_box'));
        fprintf('Monte Carlo results saved to: %s\n', outDir);
    end
    if ~p.Results.Show
        close(f1);
        close(f2);
    end
end
end

function print_summary(mc)
info = mc.info;
fprintf('\nMonte Carlo summary: %d runs, target %.2g m\n', mc.n_runs, mc.cfg.target_error_m);
fprintf('%-22s %8s %8s %8s %8s %8s %9s\n', 'Method', 'Mean', '+/-95CI', 'Median', 'P90', 'RMSE', '<=target');
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(mc.summary, key), continue; end
    s = mc.summary.(key);
    fprintf('%-22s %8.3f %8.3f %8.3f %8.3f %8.3f %7.1f %%\n', info.names{k}, s.mean_err, ...
        s.mean_ci95, s.median_err, s.p90_err, s.rmse_err, 100 * s.frac_under_target);
end
end

function write_summary_csv(mc, filepath)
info = mc.info;
keys = {}; names = {}; M = [];
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(mc.summary, key), continue; end
    s = mc.summary.(key);
    keys{end + 1, 1} = key; %#ok<AGROW>
    names{end + 1, 1} = info.names{k}; %#ok<AGROW>
    M(end + 1, :) = [s.mean_err, s.mean_ci95, s.median_err, s.p90_err, s.max_err, ...
        s.std_err, s.rmse_err, s.frac_under_target, s.n]; %#ok<AGROW>
end
T = table(keys, names, M(:, 1), M(:, 2), M(:, 3), M(:, 4), M(:, 5), M(:, 6), M(:, 7), ...
    M(:, 8), M(:, 9), 'VariableNames', {'method', 'name', 'mean_m', 'mean_ci95_m', ...
    'median_m', 'p90_m', 'max_m', 'std_m', 'rmse_m', 'frac_under_target', 'n'});
writetable(T, filepath);
end

function write_errors_csv(mc, filepath)
keys = fieldnames(mc.summary);
nRuns = mc.n_runs;
N = numel(mc.t);
runIdx = repmat((1:nRuns)', 1, N);
stepIdx = repmat(1:N, nRuns, 1);
tt = mc.t(:);
tabs = cell(1, numel(keys));
for i = 1:numel(keys)
    E = mc.errors.(keys{i});
    tabs{i} = table(runIdx(:), stepIdx(:), tt(stepIdx(:)), ...
        repmat({keys{i}}, nRuns * N, 1), E(:), ...
        'VariableNames', {'run', 'step', 't', 'method', 'err_m'});
end
writetable(vertcat(tabs{:}), filepath);
end

function write_json(cfg, filepath)
try
    txt = jsonencode(cfg, 'PrettyPrint', true);
catch
    txt = jsonencode(cfg);
end
fid = fopen(filepath, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
end
