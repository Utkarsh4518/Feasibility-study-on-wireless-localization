function fig = plot_trajectory_panels(res, cfg, varargin)
% PLOT_TRAJECTORY_PANELS  One panel per method: estimate coloured by its error.
%
% fig = plot_trajectory_panels(res, cfg)
% fig = plot_trajectory_panels(res, cfg, 'Visible', 'off')
%
% Grey line = ground truth, dots = the method's estimate coloured by the
% instantaneous error (same colour scale in every panel), squares = anchors.
% Separate panels avoid the unreadable overlay of many paths in one axes.

p = inputParser;
addParameter(p, 'Visible', 'on');
parse(p, varargin{:});

info = res.info;
show = {'rss', 'rss_kf', 'aoa', 'rtt', 'fusion', 'ekf'};
keys = {};
for k = 1:numel(show)
    if any(isfinite(res.est.(show{k}).x))
        keys{end + 1} = show{k}; %#ok<AGROW>
    end
end

fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 1000 650]);
tl = tiledlayout(fig, 'flow', 'TileSpacing', 'compact', 'Padding', 'compact');

A = cfg.anchor_pos;
allx = [res.true_x(:); A(:, 1)];
ally = [res.true_y(:); A(:, 2)];
pad = 0.6;
cmax = 2 * cfg.target_error_m;

ax = [];
for i = 1:numel(keys)
    key = keys{i};
    idx = find(strcmp(info.keys, key));
    ax = nexttile(tl);
    hold(ax, 'on');
    style_axes(ax);
    plot(ax, res.true_x, res.true_y, '-', 'Color', [0.78 0.78 0.78], 'LineWidth', 4);
    e = res.err.(key);
    ok = isfinite(e);
    scatter(ax, res.est.(key).x(ok), res.est.(key).y(ok), 16, e(ok), 'filled');
    plot(ax, A(:, 1), A(:, 2), 's', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 7);
    colormap(ax, parula);
    caxis(ax, [0 cmax]);
    axis(ax, 'equal');
    xlim(ax, [min(allx) - pad, max(allx) + pad]);
    ylim(ax, [min(ally) - pad, max(ally) + pad]);
    title(ax, sprintf('%s  (mean %.2f m)', info.names{idx}, mean(e(ok))), 'FontSize', 11);
    xlabel(ax, 'x [m]');
    ylabel(ax, 'y [m]');
end
if ~isempty(ax)
    cb = colorbar(ax);
    cb.Layout.Tile = 'east';
    cb.Label.String = sprintf('Position error [m] (saturates at %.2g m)', cmax);
end
title(tl, 'Estimated vs true path per method (simulation)');
end
