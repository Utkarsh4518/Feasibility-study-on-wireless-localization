function [x, y] = estimate_position_ls(distances, anchors)
% ESTIMATE_POSITION_LS  Deprecated wrapper kept for old scripts.
%
% [x, y] = estimate_position_ls(distances, anchors)
%
% Forwards to estimate_position_ranges (weighted nonlinear least squares), which
% replaced the linearised reference-anchor formulation (it degenerated when
% anchors were duplicated, e.g. WiFi + BLE links to the same anchor).
% Equal weights are used.
%
% See also: estimate_position_ranges.

p = estimate_position_ranges(anchors, distances(:), 1);
x = p(1);
y = p(2);
end
