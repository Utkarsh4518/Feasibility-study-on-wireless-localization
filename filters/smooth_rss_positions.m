function [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, win)
% SMOOTH_RSS_POSITIONS  Moving-average smoothing of RSS-based position estimates.
%
% [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, win)
%
% Inputs:
%   est_x, est_y - Nx1 raw position estimates [m]
%   win          - Window length for movmean (scalar integer)
%
% Outputs:
%   est_x_smooth, est_y_smooth - Nx1 smoothed positions [m]
%
% Assumptions:
%   - Positions are temporally ordered; smoothing reduces high-frequency noise.
%
% Limitations:
%   - Boundary effects at start/end of sequence (shorter effective window).
%   - No model of motion; constant window may blur fast maneuvers.

est_x_smooth = smoothdata(est_x(:), 'movmean', win);
est_y_smooth = smoothdata(est_y(:), 'movmean', win);
end
