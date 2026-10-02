function fig = plot_crlb_map(cfg, truth_x, truth_y, varargin)
% PLOT_CRLB_MAP  Map of the best achievable position accuracy for the anchor layout.
%
% fig = plot_crlb_map(cfg)
% fig = plot_crlb_map(cfg, truth_x, truth_y, 'Visible', 'off')
%
% Heat map of sqrt(trace(J^-1)) [m] over the room (Cramer-Rao bound for a
% single snapshot using every enabled link). Dark = accurate, bright = poor;
% the colour scale adapts to the data range. A white contour marks the accuracy
% target when the bound crosses it somewhere on the map; anchors are black squares; the
% optional path is drawn on top. Shows where the anchor geometry supports the
% target and where it does not (outside the anchor hull, near the anchor line).

if nargin < 2, truth_x = []; truth_y = []; end
p = inputParser;
addParameter(p, 'Visible', 'on');
addParameter(p, 'Resolution', 70);
parse(p, varargin{:});

A = cfg.anchor_pos;
pad = 1.5;
xs = linspace(min(A(:, 1)) - pad, max(A(:, 1)) + pad, p.Results.Resolution);
ys = linspace(min(A(:, 2)) - pad, max(A(:, 2)) + pad, p.Results.Resolution);
Z = compute_crlb_map(cfg, xs, ys);

fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 640 560]);
ax = axes(fig);
hold(ax, 'on');
h = imagesc(ax, xs, ys, Z);
set(h, 'AlphaData', ~isnan(Z));
set(ax, 'YDir', 'normal', 'Color', [0.92 0.92 0.92]);
colormap(ax, parula);
zmax = max(simple_percentile(Z, 98), 1e-3);
caxis(ax, [0, zmax]);
hasContour = min(Z(:)) < cfg.target_error_m && max(Z(:)) > cfg.target_error_m;
if hasContour
    contour(ax, xs, ys, Z, [cfg.target_error_m cfg.target_error_m], 'w-', 'LineWidth', 1.8);
end
if ~isempty(truth_x)
    plot(ax, truth_x, truth_y, '-', 'Color', [1 1 1], 'LineWidth', 2.5);
    plot(ax, truth_x, truth_y, '-', 'Color', [0.84 0.37 0], 'LineWidth', 1.2);
end
plot(ax, A(:, 1), A(:, 2), 's', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'MarkerSize', 9);
for i = 1:size(A, 1)
    text(ax, A(i, 1) + 0.12, A(i, 2) + 0.12, sprintf('A%d', i), 'Color', 'w', ...
        'FontWeight', 'bold', 'FontSize', 11);
end
axis(ax, 'equal');
xlim(ax, [xs(1) xs(end)]);
ylim(ax, [ys(1) ys(end)]);
style_axes(ax);
set(ax, 'Layer', 'top');
cb = colorbar(ax);
cb.Label.String = sprintf('RMSE lower bound [m] (saturates at %.2g m)', zmax);
xlabel(ax, 'x [m]');
ylabel(ax, 'y [m]');
title(ax, sprintf('Best achievable accuracy, layout "%s"', cfg.anchor_layout), 'Interpreter', 'none');
if hasContour
    subtitle(ax, sprintf('white contour = %.2g m target', cfg.target_error_m));
else
    subtitle(ax, sprintf('bound below the %.2g m target everywhere on this map (max %.2g m)', ...
        cfg.target_error_m, max(Z(:))));
end
end
