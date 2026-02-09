function [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad, weights)
% AOA_LOCALIZATION_WLS  Weighted least-squares position from angle-of-arrival.
%
% [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad)
% [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad, weights)
%
% Inputs:
%   anchor_pos - Nx2 [x_i, y_i] anchor positions [m]
%   aoa_rad    - Nx1 angles [rad] from anchor to agent (measured at anchor)
%   weights    - (optional) Nx1 weights; default ones
%
% Outputs:
%   x_est, y_est - Estimated agent position [m]
%
% Assumptions:
%   - Each AoA defines a line (bearing); agent at intersection. WLS minimizes
%     weighted squared distance to these lines.
%   - 2D plane; angles in radians.
%
% Limitations:
%   - No covariance output; not robust to outliers. Poor geometry degrades accuracy.
%
% See also: estimate_position_aoa_wls (wrapper with same interface).

Nloc = size(anchor_pos, 1);
A = zeros(Nloc, 2);
b = zeros(Nloc, 1);

for i = 1:Nloc
    xi = anchor_pos(i,1); yi = anchor_pos(i,2);
    theta = aoa_rad(i);
    n = [sin(theta); -cos(theta)];
    A(i,:) = n';
    b(i)   = n' * [xi; yi];
end

if nargin < 3 || isempty(weights)
    W = eye(Nloc);
else
    W = diag(weights(:));
end

x_opt = (A' * W * A) \ (A' * W * b);
x_est = x_opt(1);
y_est = x_opt(2);
end
