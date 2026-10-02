function T = run_sweep(cfg, param, values, nRuns, varargin)
% RUN_SWEEP  Monte Carlo at each value of one config parameter.
%
% T = run_sweep(cfg, param, values, nRuns)
% T = run_sweep(cfg, param, values, nRuns, 'OutDir', folder, 'Show', true)
%
% Inputs:
%   cfg    - base config
%   param  - dotted field path, e.g. 'noise_scale.aoa', 'noise_scale.rtt',
%            'fusion_weight_kf', 'smooth_win'; or 'anchor_layout' with values
%            being layout names (see anchor_layouts)
%   values - numeric vector, or cell array (layout names)
%   nRuns  - Monte Carlo runs per value (default 20)
%
% Output T (table, one row per value x method):
%   param, value, value_num, method, mean_err, ci95, median_err, p90_err,
%   rmse_err, frac_under_target
%
% Examples:
%   run_sweep(cfg, 'noise_scale.aoa', [0.5 1 2 4], 20)
%   run_sweep(cfg, 'anchor_layout', {'model','triangle','four_corners','collinear'}, 20)
%
% With 'OutDir' it writes sweep_<param>.csv and fig_sweep_<param>.png/.pdf.

if nargin < 4 || isempty(nRuns), nRuns = 20; end
p = inputParser;
addParameter(p, 'OutDir', '');
addParameter(p, 'Show', false);
parse(p, varargin{:});

setup_paths();
cfg = validate_config(cfg);
if ~iscell(values)
    values = num2cell(values);
end

info = method_info('rss_ls');
pcol = {}; vcol = {}; vnum = []; mcol = {};
M = [];
for iv = 1:numel(values)
    v = values{iv};
    cv = set_cfg_param(cfg, param, v);
    fprintf('Sweep %s = %s (%d runs)\n', param, value_string(v), nRuns);
    mc = run_monte_carlo(cv, nRuns, 'Verbose', false);
    for k = 1:numel(info.keys)
        key = info.keys{k};
        if ~isfield(mc.summary, key), continue; end
        s = mc.summary.(key);
        pcol{end + 1, 1} = param; %#ok<AGROW>
        vcol{end + 1, 1} = value_string(v); %#ok<AGROW>
        if isnumeric(v), vnum(end + 1, 1) = v; else, vnum(end + 1, 1) = NaN; end %#ok<AGROW>
        mcol{end + 1, 1} = key; %#ok<AGROW>
        M(end + 1, :) = [s.mean_err, s.mean_ci95, s.median_err, s.p90_err, ...
            s.rmse_err, s.frac_under_target]; %#ok<AGROW>
    end
end
T = table(pcol, vcol, vnum, mcol, M(:, 1), M(:, 2), M(:, 3), M(:, 4), M(:, 5), M(:, 6), ...
    'VariableNames', {'param', 'value', 'value_num', 'method', 'mean_err', 'ci95', ...
    'median_err', 'p90_err', 'rmse_err', 'frac_under_target'});

if ~isempty(p.Results.OutDir) || p.Results.Show
    vis = 'off';
    if p.Results.Show, vis = 'on'; end
    fig = plot_sweep(T, cfg, 'Visible', vis);
    if ~isempty(p.Results.OutDir)
        outDir = p.Results.OutDir;
        if ~isfolder(outDir), mkdir(outDir); end
        tag = strrep(param, '.', '_');
        writetable(T, fullfile(outDir, ['sweep_' tag '.csv']));
        export_figure(fig, fullfile(outDir, ['fig_sweep_' tag]));
        fprintf('Sweep saved to: %s\n', outDir);
    end
    if ~p.Results.Show, close(fig); end
end
end

function s = value_string(v)
if isnumeric(v)
    s = sprintf('%g', v);
else
    s = char(v);
end
end
