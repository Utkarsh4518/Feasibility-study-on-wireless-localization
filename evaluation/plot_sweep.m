function fig = plot_sweep(T, cfg, varargin)
% PLOT_SWEEP  Mean error vs a swept parameter, one line per method, with 95% CI.
%
% fig = plot_sweep(T, cfg)
% fig = plot_sweep(T, cfg, 'Methods', {'aoa','rtt','fusion','ekf'}, 'Visible', 'off')
%
% T - table from run_sweep with columns
%       param, value (string), value_num (NaN for categorical values),
%       method (key), mean_err, ci95
%
% Numeric parameters give a line plot with a shaded confidence band;
% categorical ones (e.g. anchor layouts) give one marker + error bar per level.

p = inputParser;
addParameter(p, 'Visible', 'on');
addParameter(p, 'Methods', {'aoa', 'rtt', 'fusion', 'ekf'});
parse(p, varargin{:});

info = method_info();
fig = figure('Visible', p.Results.Visible, 'Color', 'w', 'Position', [100 100 700 450]);
ax = axes(fig);
hold(ax, 'on');
style_axes(ax);

[levels, ~] = unique(T.value, 'stable');
numeric = all(isfinite(T.value_num));
for im = 1:numel(p.Results.Methods)
    key = p.Results.Methods{im};
    k = find(strcmp(info.keys, key));
    rows = strcmp(T.method, key);
    if ~any(rows), continue; end
    Tm = T(rows, :);
    if numeric
        [x, order] = sort(Tm.value_num);
    else
        [~, x] = ismember(Tm.value, levels);
        [x, order] = sort(x);
    end
    y = Tm.mean_err(order);
    ci = Tm.ci95(order);
    ci(~isfinite(ci)) = 0;
    c = info.colors(k, :);
    if numeric
        fill(ax, [x; flipud(x)], [y - ci; flipud(y + ci)], c, 'FaceAlpha', 0.15, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(ax, x, y, '-o', 'Color', c, 'LineWidth', 1.8, 'MarkerSize', 5, ...
            'MarkerFaceColor', c, 'DisplayName', info.names{k});
    else
        errorbar(ax, x, y, ci, '-o', 'Color', c, 'LineWidth', 1.8, 'MarkerSize', 6, ...
            'MarkerFaceColor', c, 'CapSize', 6, 'DisplayName', info.names{k});
    end
end
yline(ax, cfg.target_error_m, '--', sprintf('%.2g m target', cfg.target_error_m), ...
    'Color', [0.25 0.25 0.25], 'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
if ~numeric
    set(ax, 'XTick', 1:numel(levels), 'XTickLabel', levels, 'TickLabelInterpreter', 'none');
    xlim(ax, [0.5, numel(levels) + 0.5]);
end
xlabel(ax, strrep(T.param{1}, '_', '\_'));
ylabel(ax, 'Mean position error [m]');
title(ax, 'Sensitivity sweep (simulation, 95% CI over runs)');
legend(ax, 'Location', 'northwest', 'Box', 'off');
end
