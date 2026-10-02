function [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad, weights)
% AOA_LOCALIZATION_WLS  Deprecated wrapper kept for old scripts.
%
% [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad)
% [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad, weights)
%
% Forwards to estimate_position_aoa_wls, the single implementation.
% "weights" are interpreted as inverse bearing variances (1 / sigma_rad^2);
% omit them to use a common 2 degree bearing std.
%
% See also: estimate_position_aoa_wls.

if nargin < 3 || isempty(weights)
    sigma = deg2rad(2);
else
    sigma = 1 ./ sqrt(weights(:));
end
p = estimate_position_aoa_wls(anchor_pos, aoa_rad, sigma);
x_est = p(1);
y_est = p(2);
end
