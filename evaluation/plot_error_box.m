function fig = plot_error_box(err, cfg, info, varargin)
% PLOT_ERROR_BOX  Box plot of the position error per method (no toolbox needed).
%
% fig = plot_error_box(err, cfg, info)
% fig = plot_error_box(err, cfg, info, 'Visible', 'off', 'Title', '...')
%
% err - struct: method key -> array of errors [m] (any shape; pooled, e.g.
%       runs x time steps from run_monte_carlo)
%
% Box = interquartile range, thick line = median, + = mean,
% whiskers = 5th to 95th percentile. Dashed line = accuracy target.

p = inputParser;
addParameter(p, 'Visible', 'on');
addParameter(p, 'Title', 'Position error per method (simulation)');
parse(p, varargin{:});

fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 760 450]);
ax = axes(fig);
hold(ax, 'on');
style_axes(ax);

pos = 0;
labels = {};
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(err, key), continue; end
    e = err.(key)(:);
    e = e(isfinite(e));
    if isempty(e), continue; end
    pos = pos + 1;
    c = info.colors(k, :);
    q1 = simple_percentile(e, 25);
    q2 = simple_percentile(e, 50);
    q3 = simple_percentile(e, 75);
    lo = simple_percentile(e, 5);
    hi = simple_percentile(e, 95);
    patch(ax, pos + [-1 1 1 -1] * 0.28, [q1 q1 q3 q3], c, 'FaceAlpha', 0.35, ...
        'EdgeColor', c, 'LineWidth', 1.2);
    plot(ax, pos + [-1 1] * 0.28, [q2 q2], '-', 'Color', c, 'LineWidth', 2.6);
    plot(ax, [pos pos], [lo q1], '-', 'Color', c, 'LineWidth', 1.2);
    plot(ax, [pos pos], [q3 hi], '-', 'Color', c, 'LineWidth', 1.2);
    plot(ax, pos, mean(e), '+', 'Color', c, 'MarkerSize', 9, 'LineWidth', 1.6);
    labels{pos} = info.names{k}; %#ok<AGROW>
end
yline(ax, cfg.target_error_m, '--', sprintf('%.2g m target', cfg.target_error_m), ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');
set(ax, 'XTick', 1:pos, 'XTickLabel', labels, 'XTickLabelRotation', 25);
xlim(ax, [0.4, pos + 0.6]);
ylim(ax, [0, inf]);
ylabel(ax, 'Position error [m]');
title(ax, p.Results.Title);
subtitle(ax, 'box: IQR   line: median   +: mean   whiskers: 5th-95th percentile');
end
