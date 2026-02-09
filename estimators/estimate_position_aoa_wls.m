function [x_est, y_est] = estimate_position_aoa_wls(anchors, aoa_rad, weights)
% ESTIMATE_POSITION_AOA_WLS  Position from angle-of-arrival via weighted least squares.
%
% [x_est, y_est] = estimate_position_aoa_wls(anchors, aoa_rad)
% [x_est, y_est] = estimate_position_aoa_wls(anchors, aoa_rad, weights)
%
% Inputs:
%   anchors - Nx2 [x_i, y_i] anchor positions [m]
%   aoa_rad - Nx1 angles [rad] from anchor to agent (measured at anchor)
%   weights - (optional) Nx1 weights per bearing; default ones
%
% Outputs:
%   x_est, y_est - Estimated agent position [m]
%
% Assumptions:
%   - Each AoA defines a ray (line) from anchor to agent; agent is at the
%     intersection of these rays. WLS minimizes weighted squared distance
%     to the lines.
%   - Angles are in radians; measurement errors are zero-mean (WLS optimal
%     for Gaussian angle errors).
%   - 2D geometry; all anchors and agent in same plane.
%
% Limitations:
%   - Linear formulation; for large angle errors or poor geometry, solution
%     can be biased. No covariance output.
%   - Requires at least 2 anchors; geometry (anchor spread) affects accuracy.

if nargin < 3 || isempty(weights)
    [x_est, y_est] = aoa_localization_wls(anchors, aoa_rad);
else
    [x_est, y_est] = aoa_localization_wls(anchors, aoa_rad, weights);
end
end
