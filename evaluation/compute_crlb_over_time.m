function crlb_xy = compute_crlb_over_time(est_x, est_y, anchor_x, anchor_y, sigma_rss, PL0, n)
% COMPUTE_CRLB_OVER_TIME  Cramér-Rao lower bound for RSS-based localization.
%
% crlb_xy = compute_crlb_over_time(est_x, est_y, anchor_x, anchor_y, sigma_rss, PL0, n)
%
% Inputs:
%   est_x, est_y - Estimated or true position over time (Nx1 each)
%   anchor_x, anchor_y - Anchor coordinates (1xM each)
%   sigma_rss - Std of RSS measurement noise [dB]
%   PL0       - Path loss at reference distance [dB]
%   n         - Path loss exponent
%
% Output:
%   crlb_xy - Nx2 [sigma_x^2, sigma_y^2] lower bound per timestep

lambda = 10 / (log(10) * n);
sigma2 = sigma_rss^2;

N = length(est_x);
num_anchors = length(anchor_x);
crlb_xy = zeros(N, 2);

for k = 1:N
    x = est_x(k);
    y = est_y(k);
    J = zeros(2, 2);

    for i = 1:num_anchors
        dx = x - anchor_x(i);
        dy = y - anchor_y(i);
        d_sq = dx^2 + dy^2;
        if d_sq < 1e-6
            continue;
        end
        J = J + (lambda^2 / sigma2) * ([dx; dy] * [dx dy]) / d_sq;
    end

    if rank(J) == 2
        crlb = inv(J);
        crlb_xy(k, :) = diag(crlb)';
    else
        crlb_xy(k, :) = [NaN, NaN];
    end
end
end
