function [kx, ky, cov] = kalman_filter_cv(zx, zy, dts, cfg, R_seq)
% KALMAN_FILTER_CV  Constant-velocity Kalman filter on position measurements.
%
% [kx, ky, cov] = kalman_filter_cv(zx, zy, dts, cfg, R_seq)
%
% Inputs:
%   zx, zy - Nx1 position measurements [m]; NaN = no measurement (predict only)
%   dts    - Nx1 time step before each sample [s] (dts(1) unused)
%   cfg    - config struct (kf_sigma_a, kf_R_floor_m2, kf_chi2_gate,
%            kf_max_rejects, kf_P0_diag)
%   R_seq  - 2x2xN measurement noise covariance per step [m^2]
%
% Outputs:
%   kx, ky - Nx1 filtered position [m]
%   cov    - 2x2xN position covariance of the filtered state
%
% Notes:
%   - The measurement noise is an input and is never derived from ground truth
%     (the earlier kalman_filter_rss estimated R from true - estimate).
%   - Mahalanobis gating (kalman_update). After cfg.kf_max_rejects consecutive
%     rejections the filter re-initialises on the current measurement, so a
%     bad stretch cannot make it reject every later measurement forever.
%
% See also: kalman_update, cv_matrices.

zx = zx(:); zy = zy(:); dts = dts(:);
N = numel(zx);
P0 = diag(cfg.kf_P0_diag(:));
kx = nan(N, 1);
ky = nan(N, 1);
cov = nan(2, 2, N);

x = zeros(4, 1);
P = P0;
started = false;
rejects = 0;
for k = 1:N
    z = [zx(k); zy(k)];
    have = all(isfinite(z));
    if ~started
        if ~have, continue; end
        x = [z(1); 0; z(2); 0];
        P = P0;
        started = true;
    elseif have
        R = R_seq(:, :, k) + cfg.kf_R_floor_m2 * eye(2);
        [x, P, accepted] = kalman_update(x, P, z, dts(k), cfg, R);
        if accepted
            rejects = 0;
        else
            rejects = rejects + 1;
            if rejects >= cfg.kf_max_rejects
                x = [z(1); 0; z(2); 0];
                P = P0;
                rejects = 0;
            end
        end
    else
        [A, Q] = cv_matrices(dts(k), cfg.kf_sigma_a);
        x = A * x;
        P = A * P * A' + Q;
    end
    kx(k) = x(1);
    ky(k) = x(3);
    cov(:, :, k) = P([1 3], [1 3]);
end
end
