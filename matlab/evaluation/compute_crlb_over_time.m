function bound = compute_crlb_over_time(cfg, x, y)
% COMPUTE_CRLB_OVER_TIME  Cramer-Rao lower bound on 2D RMSE along a path.
%
% bound = compute_crlb_over_time(cfg, x, y)
%
% Inputs:
%   cfg  - config struct (anchors, enabled modalities, channel, noise)
%   x, y - Nx1 positions at which to evaluate the bound (normally ground truth)
%
% Output:
%   bound - Nx1, sqrt(trace(J^-1)) in metres: a lower bound on the RMS position
%           error of any unbiased single-snapshot estimator that uses all
%           enabled links. NaN where J is singular (e.g. agent on the line
%           through collinear anchors).
%
% A filter that exploits motion over time (Kalman, EKF) can go below this
% snapshot bound; static estimators (AoA, RTT, fusion of snapshots) cannot.
%
% See also: fisher_information, compute_crlb_map.

x = x(:); y = y(:);
bound = nan(numel(x), 1);
for k = 1:numel(x)
    J = fisher_information(cfg, x(k), y(k));
    if rcond(J) > 1e-12
        bound(k) = sqrt(trace(inv(J)));
    end
end
end
