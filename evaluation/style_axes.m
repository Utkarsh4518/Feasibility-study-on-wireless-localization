function style_axes(ax)
% STYLE_AXES  Common axes style for all project figures.
%
% style_axes(ax)
%
% Light grid, outward ticks, closed box, 11 pt font. Colours per method come
% from method_info so a method has the same colour in every figure.

set(ax, 'FontSize', 11, 'LineWidth', 0.8, 'Box', 'on', 'TickDir', 'out', ...
    'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.15, 'Layer', 'top');
end
