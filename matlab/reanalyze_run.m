function res = reanalyze_run(runDir, cfg, varargin)
% REANALYZE_RUN  Re-run the analysis on a saved run (no Simulink needed).
%
% res = reanalyze_run(runDir)
% res = reanalyze_run(runDir, cfg)
% res = reanalyze_run(runDir, cfg, 'OutDir', folder, 'Show', false)
%
% Loads meas.mat written by run_experiment / run_simulated_experiment and runs
% analyze_run again, optionally with a modified config (different filter
% settings, fusion method, enabled modalities...). Anchors and channel in cfg
% must still describe the data that were recorded.
%
% 'OutDir' - folder for a new report ('' = none, default)
% 'Show'   - show figures (default true)

setup_paths();
S = load(fullfile(runDir, 'meas.mat'));
if nargin < 2 || isempty(cfg)
    cfg = S.cfg;
end
cfg = validate_config(cfg);

p = inputParser;
addParameter(p, 'OutDir', '');
addParameter(p, 'Show', true);
parse(p, varargin{:});

res = analyze_run(S.meas, cfg);
report_run(res, cfg, p.Results.OutDir, 'Show', p.Results.Show);
end
