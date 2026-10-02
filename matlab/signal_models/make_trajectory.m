function [t, x, y] = make_trajectory(tc)
% MAKE_TRAJECTORY  Sample a piecewise-linear path at constant speed.
%
% [t, x, y] = make_trajectory(cfg.trajectory)
%
% Inputs (fields of tc):
%   waypoints - Mx2 [x y] corner points [m]
%   speed_mps - constant speed [m/s]
%   dt        - sample period [s]
%
% Outputs:
%   t, x, y   - Nx1 time [s] and position [m]

wp = tc.waypoints;
seg = hypot(diff(wp(:, 1)), diff(wp(:, 2)));
keep = [true; seg > 1e-9];             % drop repeated waypoints (zero-length segments)
wp = wp(keep, :);
seg = hypot(diff(wp(:, 1)), diff(wp(:, 2)));
s = [0; cumsum(seg)];

step = tc.speed_mps * tc.dt;
sk = (0:step:s(end) + 1e-9)';
sk = min(sk, s(end));
x = interp1(s, wp(:, 1), sk);
y = interp1(s, wp(:, 2), sk);
t = (0:numel(sk) - 1)' * tc.dt;
end
