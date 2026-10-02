function [A, Q] = cv_matrices(dt, sigma_a)
% CV_MATRICES  Constant-velocity model matrices, state [x; vx; y; vy].
%
% [A, Q] = cv_matrices(dt, sigma_a)
%
% A - 4x4 state transition; Q - 4x4 white-noise-acceleration process noise
% with acceleration std sigma_a [m/s^2].

A = [1 dt 0  0;
     0  1 0  0;
     0  0 1 dt;
     0  0 0  1];
q = sigma_a ^ 2;
Q = q * [dt^4/4 dt^3/2 0 0;
         dt^3/2 dt^2   0 0;
         0 0 dt^4/4 dt^3/2;
         0 0 dt^3/2 dt^2];
end
