function fig = plot_error_cdf(err, cfg, info, varargin)
% PLOT_ERROR_CDF  Empirical CDF of the position error for every method.
%
% fig = plot_error_cdf(err, cfg, info)
% fig = plot_error_cdf(err, cfg, info, 'Visible', 'off', 'Title', '...')
%
% err  - struct: method key -> array of errors [m] (any shape; pooled)
% info - method registry (method_info)
%
% The headline localization plot: the curve value at the dashed line is the
% fraction of samples with error <= cfg.target_error_m, also written in the
% legend.

p = inputParser;
addParameter(p, 'Visible', 'on');
addParameter(p, 'Title', 'Position error distribution (simulation)');
parse(p, varargin{:});

fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 700 450]);
ax = axes(fig);
hold(ax, 'on');
style_axes(ax);

xmax = 0;
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(err, key), continue; end
    e = err.(key)(:);
    e = sort(e(isfinite(e)));
    if isempty(e), continue; end
    F = (1:numel(e))' / numel(e);
    lw = 1.6;
    if any(strcmp(key, {'fusion', 'ekf'})), lw = 2.6; end
    stairs(ax, [0; e], [0; F], 'LineWidth', lw, 'Color', info.colors(k, :), ...
        'DisplayName', sprintf('%s  (%.0f%% \\leq %.2g m)', info.names{k}, ...
        100 * mean(e <= cfg.target_error_m), cfg.target_error_m));
    xmax = max(xmax, simple_percentile(e, 99));
end
xline(ax, cfg.target_error_m, '--', sprintf('%.2g m target', cfg.target_error_m), ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom', ...
    'HandleVisibility', 'off');
xlim(ax, [0, max(xmax * 1.1, 1.5 * cfg.target_error_m)]);
ylim(ax, [0 1]);
xlabel(ax, 'Position error [m]');
ylabel(ax, 'Cumulative probability');
title(ax, p.Results.Title);
legend(ax, 'Location', 'southeast', 'Box', 'off');
end
