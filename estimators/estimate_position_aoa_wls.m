function [p, C] = estimate_position_aoa_wls(anchors, theta_rad, sigma_rad)
% ESTIMATE_POSITION_AOA_WLS  Position from bearings by weighted least squares.
%
% [p, C] = estimate_position_aoa_wls(anchors, theta_rad, sigma_rad)
%
% Inputs:
%   anchors   - Kx2 anchor positions of each bearing [m]
%   theta_rad - K bearings anchor -> agent [rad]; NaN entries are ignored
%   sigma_rad - K (or scalar) bearing std [rad]
%
% Outputs:
%   p - 1x2 estimated position [x y]; [NaN NaN] if under-determined
%   C - 2x2 covariance of the estimate
%
% Method: each bearing defines a line; the signed distance of p to line i is
% n_i'(p - a_i) with n_i = [sin th_i; -cos th_i]. A bearing error dth moves the
% line by about d_i*dth at the agent, so the weights are 1/(d_i*sigma_i)^2, where
% d_i comes from a first unweighted pass (two passes in total).
%
% Assumptions:
%   - 2D; zero-mean Gaussian bearing errors.
% Limitations:
%   - Linearised; poor anchor geometry or large angle errors degrade accuracy.

th = theta_rad(:);
sg = sigma_rad(:);
if isscalar(sg), sg = repmat(sg, size(th)); end
ok = isfinite(th) & isfinite(sg);

p = [NaN NaN];
C = nan(2, 2);
if sum(ok) < 2
    return;
end
a = anchors(ok, :);
th = th(ok);
sg = sg(ok);

n = [sin(th), -cos(th)];
b = sum(n .* a, 2);
w = ones(numel(th), 1);
for pass = 1:2
    H = n' * (w .* n);
    if rcond(H) < 1e-12
        p = [NaN NaN];
        return;
    end
    p = (H \ (n' * (w .* b)))';
    d = max(hypot(p(1) - a(:, 1), p(2) - a(:, 2)), 0.5);
    w = 1 ./ (d .* sg) .^ 2;
end
H = n' * (w .* n);
if rcond(H) > 1e-12
    C = inv(H);
end
end
