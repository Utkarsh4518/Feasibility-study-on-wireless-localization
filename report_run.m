function figs = report_run(res, cfg, outDir, varargin)
% REPORT_RUN  Print metrics, draw the standard figures, optionally save a report.
%
% figs = report_run(res, cfg, outDir)
% figs = report_run(res, cfg, outDir, 'Show', false)
%
% Inputs:
%   res    - result from analyze_run
%   cfg    - config used
%   outDir - folder for the saved report; [] or '' = do not save
%   'Show' - (default true) leave the figures open; false closes them after saving

p = inputParser;
addParameter(p, 'Show', true);
parse(p, varargin{:});

compute_metrics(res, cfg);

if p.Results.Show
    vis = 'on';
else
    vis = 'off';
end
figs = plot_results(res, cfg, 'Visible', vis);

if ~isempty(outDir)
    run_evaluation_report(res, cfg, outDir, figs);
end
if ~p.Results.Show
    names = fieldnames(figs);
    for i = 1:numel(names)
        close(figs.(names{i}));
    end
end
end
