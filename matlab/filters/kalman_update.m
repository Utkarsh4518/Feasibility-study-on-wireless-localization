function [x_new, P_new, accepted] = kalman_update(x, P, measurement, dt, config, R)
% KALMAN_UPDATE  Single predict-and-update step for constant-velocity 2D model.
%
% [x_new, P_new, accepted] = kalman_update(x, P, measurement, dt, config, R)
%
% Inputs:
%   x          - 4x1 state [x; vx; y; vy] [m], [m/s]
%   P          - 4x4 state covariance
%   measurement - 2x1 or 1x2 position measurement [x; y] [m]
%   dt         - Time step [s]
%   config     - Struct with kf_sigma_a, kf_chi2_gate
%   R          - 2x2 measurement noise covariance (or 1x2 diag)
%
% Outputs:
%   x_new   - 4x1 updated state
%   P_new   - 4x4 updated covariance
%   accepted - true if measurement passed Mahalanobis gating (used), else false
%
% Assumptions:
%   - Constant velocity between steps (white-noise acceleration process).
%   - Linear observation: z = H*x with H = [1 0 0 0; 0 0 1 0].
%   - Gaussian process and measurement noise; R is known or estimated.
%
% Limitations:
%   - Linear model only; no turns or dynamics change.
%   - Outlier rejection via chi-squared gate; may reject good measurements
%     if gate is too tight. Joseph form used for P update for numerical stability.

x = x(:);
measurement = measurement(:);
if numel(measurement) == 2
    z = measurement;
else
    z = measurement(1:2);
end

A = [1 dt 0  0; 0  1 0  0; 0  0 1 dt; 0  0 0  1];
H = [1 0 0 0; 0 0 1 0];

q = config.kf_sigma_a^2;
Q = q * [dt^4/4 dt^3/2 0 0; dt^3/2 dt^2 0 0; 0 0 dt^4/4 dt^3/2; 0 0 dt^3/2 dt^2];

if numel(R) == 2
    R = diag(R(:));
end
R = R(1:2, 1:2);

% Predict
x_pred = A * x;
P_pred = A * P * A' + Q;

% Update with gating
yk = z - H * x_pred;
S = H * P_pred * H' + R;
d2 = yk' / S * yk;
chi2_gate = config.kf_chi2_gate;
accepted = (d2 <= chi2_gate);

if accepted
    K = P_pred * H' / S;
    x_new = x_pred + K * yk;
    I = eye(4);
    P_new = (I - K * H) * P_pred * (I - K * H)' + K * R * K';
else
    x_new = x_pred;
    P_new = P_pred;
end
end
