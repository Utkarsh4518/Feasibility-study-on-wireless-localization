function [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, win, causal)
% SMOOTH_RSS_POSITIONS  Moving-average smoothing of position estimates.
%
% [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, win)
% [est_x_smooth, est_y_smooth] = smooth_rss_positions(est_x, est_y, win, causal)
%
% Inputs:
%   est_x, est_y - Nx1 raw position estimates [m]
%   win          - Window length (positive integer)
%   causal       - (optional, default false) true = trailing window that uses
%                  only past samples (usable online, adds lag); false = centred
%                  window (uses future samples, offline only).
%
% Outputs:
%   est_x_smooth, est_y_smooth - Nx1 smoothed positions [m]
%
% Assumptions:
%   - Positions are temporally ordered and uniformly sampled. NaNs are skipped.
%
% Limitations:
%   - Window shrinks at the start of the sequence.
%   - No motion model; a long window blurs manoeuvres and, if causal, lags them.

if nargin < 4 || isempty(causal)
    causal = false;
end
if causal
    w = [win - 1, 0];
else
    w = win;
end
est_x_smooth = movmean(est_x(:), w, 'omitnan');
est_y_smooth = movmean(est_y(:), w, 'omitnan');
end
