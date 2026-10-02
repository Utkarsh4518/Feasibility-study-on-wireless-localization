function figs = plot_results(res, cfg, varargin)
% PLOT_RESULTS  Standard figure set for one run.
%
% figs = plot_results(res, cfg)
% figs = plot_results(res, cfg, 'Visible', 'off', 'Debug', true)
%
% Figures (returned as fields of figs):
%   trajectory  one panel per method, estimate coloured by error
%   cdf         empirical error CDF per method with the accuracy target
%   error_time  error over time against the theoretical lower bound
%   crlb_map    achievable-accuracy map of the anchor layout with the path
%   debug       (only with 'Debug', true) anchor-to-agent distances
%
% The earlier TX-vs-RX sine plot (plotted a made-up reference sine, showed no
% localization information) and the overlapping per-step error lines were
% removed.

p = inputParser;
addParameter(p, 'Visible', 'on');
addParameter(p, 'Debug', false);
parse(p, varargin{:});
vis = p.Results.Visible;

figs.trajectory = plot_trajectory_panels(res, cfg, 'Visible', vis);
figs.cdf = plot_error_cdf(res.err, cfg, res.info, 'Visible', vis, ...
    'Title', 'Position error distribution (simulation, single run)');
figs.error_time = plot_error_vs_crlb(res, cfg, 'Visible', vis);
figs.crlb_map = plot_crlb_map(cfg, res.true_x, res.true_y, 'Visible', vis);

if p.Results.Debug
    A = cfg.anchor_pos;
    d = zeros(res.N, size(A, 1));
    for i = 1:size(A, 1)
        d(:, i) = hypot(res.true_x - A(i, 1), res.true_y - A(i, 2));
    end
    f = figure('Visible', vis, 'Color', 'w');
    ax = axes(f);
    plot(ax, res.t, d, 'LineWidth', 1.4);
    style_axes(ax);
    legend(ax, arrayfun(@(i) sprintf('Anchor %d', i), 1:size(A, 1), 'UniformOutput', false), ...
        'Location', 'best', 'Box', 'off');
    xlabel(ax, 'Time [s]');
    ylabel(ax, 'Distance [m]');
    title(ax, 'Anchor-to-agent distances (simulation)');
    figs.debug = f;
end
end
