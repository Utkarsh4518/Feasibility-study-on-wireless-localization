function [x, y] = trilaterate(anchor_pos, d)
% TRILATERATE  Least-squares trilateration from anchor positions and distances.
%
% [x, y] = trilaterate(anchor_pos, d)
%
% Inputs:
%   anchor_pos - Mx2 [x_i, y_i] anchor positions [m]
%   d          - Mx1 distances from agent to each anchor [m]
%
% Outputs:
%   x, y - Estimated agent position [m]
%
% See also: estimate_position_ls (same math, argument order: distances, anchors).

[x, y] = estimate_position_ls(d, anchor_pos);
end
