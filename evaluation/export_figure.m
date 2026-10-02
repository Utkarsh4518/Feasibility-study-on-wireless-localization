function export_figure(fig, basePath)
% EXPORT_FIGURE  Save a figure as <basePath>.png (300 dpi) and <basePath>.pdf (vector).
%
% export_figure(fig, basePath)
%
% Uses exportgraphics (R2020a+); falls back to saveas if that fails.

try
    exportgraphics(fig, [basePath '.png'], 'Resolution', 300);
    exportgraphics(fig, [basePath '.pdf'], 'ContentType', 'vector');
catch
    saveas(fig, [basePath '.png']);
end
end
