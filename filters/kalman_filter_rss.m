function [kf_x, kf_y] = kalman_filter_rss(est_x_smooth, est_y_smooth, dt, cfg, varargin)
% KALMAN_FILTER_RSS  Deprecated wrapper; use kalman_filter_cv.
%
% [kf_x, kf_y] = kalman_filter_rss(est_x_smooth, est_y_smooth, dt, cfg)
%
% The previous version estimated the measurement noise R from ground truth
% (var(true - estimate)), i.e. it used information a real system never has, so
% its accuracy was optimistic. Extra arguments (the old true_x, true_y) are
% ignored. R is now cfg.kf_R_fixed_m2 * I.
%
% See also: kalman_filter_cv.

if ~isempty(varargin)
    warning('localization:deprecated', ...
        'kalman_filter_rss no longer uses ground truth; extra arguments are ignored.');
end
N = numel(est_x_smooth);
R = repmat(cfg.kf_R_fixed_m2 * eye(2), [1 1 N]);
[kf_x, kf_y] = kalman_filter_cv(est_x_smooth, est_y_smooth, repmat(dt, N, 1), cfg, R);
end
