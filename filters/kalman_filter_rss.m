function [kf_x, kf_y] = kalman_filter_rss(est_x_smooth, est_y_smooth, dt, cfg, true_x, true_y)
% KALMAN_FILTER_RSS  Constant-velocity Kalman filter on smoothed RSS position estimates.
%
% [kf_x, kf_y] = kalman_filter_rss(est_x_smooth, est_y_smooth, dt, cfg, true_x, true_y)
%
% Inputs:
%   est_x_smooth, est_y_smooth - Nx1 smoothed (x,y) measurements [m]
%   dt   - Time step [s]
%   cfg  - Struct from localization_config (KF parameters)
%   true_x, true_y - Nx1 ground truth (used only to set measurement noise R)
%
% Outputs:
%   kf_x, kf_y - Nx1 filtered position estimates [m]
%
% Assumptions:
%   - Constant-velocity motion model; state [x; vx; y; vy].
%   - Measurement noise R estimated from residual (true - smooth); floor from config.
%
% Limitations:
%   - R is derived from ground truth (supervised); in practice R would be fixed or estimated offline.

N = length(est_x_smooth);
z = [est_x_smooth(:), est_y_smooth(:)];

ex = true_x(:) - est_x_smooth(:);
ey = true_y(:) - est_y_smooth(:);
Rx = max(var(ex, 'omitnan'), cfg.kf_measurement_var_floor);
Ry = max(var(ey, 'omitnan'), cfg.kf_measurement_var_floor);
R  = diag([Rx, Ry]);

x0 = [z(1,1); 0; z(1,2); 0];
P0 = diag(cfg.kf_P0_diag);

x = x0;
P = P0;
kf_x = zeros(N, 1);
kf_y = zeros(N, 1);

for k = 1:N
    zk = z(k, :)';
    [x, P, ~] = kalman_update(x, P, zk, dt, cfg, R);
    kf_x(k) = x(1);
    kf_y(k) = x(3);
end
end
