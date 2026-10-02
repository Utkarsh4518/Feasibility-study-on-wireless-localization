function out = anchor_layouts(name)
% ANCHOR_LAYOUTS  Named anchor layouts [m].
%
% pos   = anchor_layouts('model')   % Kx2 positions
% names = anchor_layouts()          % cell array of available names
%
% 'model'        anchors hard-coded in Localization_Ependorfv2.slx
% 'triangle'     equilateral triangle, 5 m side
% 'four_corners' corners of a 5 m x 5 m room (4 anchors)
% 'collinear'    nearly collinear anchors (deliberately poor geometry)
%
% The Simulink model only supports its own 3 anchors; the other layouts are
% for the pure-MATLAB simulator (run_simulated_experiment, run_sweep).

layouts = struct( ...
    'model',        [0 0; 0 5; 5 0], ...
    'triangle',     [0 0; 5 0; 2.5 4.33], ...
    'four_corners', [0 0; 5 0; 5 5; 0 5], ...
    'collinear',    [0 0; 2.5 2.6; 5 5]);

if nargin < 1
    out = fieldnames(layouts)';
    return;
end
if ~isfield(layouts, name)
    error('localization:config', 'Unknown anchor layout "%s". Available: %s', ...
        name, strjoin(fieldnames(layouts)', ', '));
end
out = layouts.(name);
end
