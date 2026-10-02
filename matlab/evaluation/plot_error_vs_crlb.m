function fig = plot_error_vs_crlb(res, cfg, varargin)
% PLOT_ERROR_VS_CRLB  Position error over time against the theoretical bound.
%
% fig = plot_error_vs_crlb(res, cfg)
% fig = plot_error_vs_crlb(res, cfg, 'Visible', 'off')
%
% Grey area = single-snapshot RMSE lower bound along the true path
% (compute_crlb_over_time). Static estimators (AoA, RTT, fusion) cannot go
% below it on average; the EKF can, because it also uses the motion over time.

p = inputParser;
addParameter(p, 'Visible', 'on');
parse(p, varargin{:});

info = res.info;
bound = compute_crlb_over_time(cfg, res.true_x, res.true_y);

fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 760 430]);
ax = axes(fig);
hold(ax, 'on');
style_axes(ax);

ok = isfinite(bound);
if any(ok)
    area(ax, res.t(ok), bound(ok), 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'none', ...
        'DisplayName', 'RMSE lower bound (snapshot)');
end
ymax = 0;
for key = {'aoa', 'rtt', 'fusion', 'ekf'}
    k = find(strcmp(info.keys, key{1}));
    e = res.err.(key{1});
    if ~any(isfinite(e)), continue; end
    plot(ax, res.t, e, '-', 'Color', info.colors(k, :), 'LineWidth', 1.4, ...
        'DisplayName', info.names{k});
    ymax = max(ymax, simple_percentile(e, 98));
end
yline(ax, cfg.target_error_m, '--', sprintf('%.2g m target', cfg.target_error_m), ...
    'Color', [0.25 0.25 0.25], 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
ylim(ax, [0, max(ymax * 1.15, 1.3 * cfg.target_error_m)]);
xlabel(ax, 'Time [s]');
ylabel(ax, 'Position error [m]');
title(ax, 'Error over time vs lower bound (simulation)');
legend(ax, 'Location', 'northeast', 'Box', 'off');
end
