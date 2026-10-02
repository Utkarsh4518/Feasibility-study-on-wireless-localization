function [p, C] = estimate_position_ranges(anchors, ranges, sigma, x0)
% ESTIMATE_POSITION_RANGES  Weighted nonlinear least-squares position from ranges.
%
% [p, C] = estimate_position_ranges(anchors, ranges, sigma)
% [p, C] = estimate_position_ranges(anchors, ranges, sigma, x0)
%
% Inputs:
%   anchors - Lx2 anchor position of each link [m] (duplicates allowed, e.g.
%             WiFi and BLE links to the same anchor)
%   ranges  - L ranges [m]; NaN entries are ignored
%   sigma   - L (or scalar) range std [m]
%   x0      - (optional) 1x2 starting point; default: centroid of the anchors
%
% Outputs:
%   p - 1x2 estimated position [x y]; [NaN NaN] if under-determined
%   C - 2x2 covariance (JtWJ)^-1 at the solution; NaN if ill-conditioned
%
% Method: Levenberg-Marquardt on sum_i ((r_i - |p - a_i|)/sigma_i)^2. Replaces
% the earlier linearised trilateration, which used the first link as a reference
% and degenerated for duplicated anchors.
%
% Assumptions:
%   - 2D, line-of-sight, zero-mean Gaussian range errors.
% Limitations:
%   - Local solver: with nearly collinear anchors a mirror-image solution exists.

ranges = ranges(:);
sigma = sigma(:);
if isscalar(sigma), sigma = repmat(sigma, size(ranges)); end
ok = isfinite(ranges) & isfinite(sigma) & sigma > 0;
a = anchors(ok, :);
r = ranges(ok);
w = 1 ./ sigma(ok) .^ 2;

p = [NaN NaN];
C = nan(2, 2);
if sum(ok) < 2 || size(unique(a, 'rows'), 1) < 2
    return;
end

if nargin < 4 || isempty(x0) || any(~isfinite(x0))
    p = mean(unique(a, 'rows'), 1);
else
    p = x0(:)';
end

lam = 1e-2;
c0 = range_cost(p, a, r, w);
for it = 1:40
    diffs = p - a;                                  % Lx2
    d = max(hypot(diffs(:, 1), diffs(:, 2)), 1e-9);
    J = diffs ./ d;                                 % d(pred range)/dp
    H = J' * (w .* J);
    g = J' * (w .* (r - d));
    step = (H + lam * diag(diag(H)) + 1e-12 * eye(2)) \ g;
    pn = p + step';
    c1 = range_cost(pn, a, r, w);
    if c1 < c0
        p = pn;
        c0 = c1;
        lam = lam * 0.3;
        if norm(step) < 1e-7, break; end
    else
        lam = lam * 5;
        if lam > 1e8, break; end
    end
end

diffs = p - a;
d = max(hypot(diffs(:, 1), diffs(:, 2)), 1e-9);
J = diffs ./ d;
H = J' * (w .* J);
if rcond(H) > 1e-12
    C = inv(H);
end
end

function c = range_cost(q, a, r, w)
d = hypot(q(1) - a(:, 1), q(2) - a(:, 2));
c = sum(w .* (r - d) .^ 2);
end
