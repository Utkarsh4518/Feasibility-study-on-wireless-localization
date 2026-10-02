function fused = fuse_inverse_covariance(parts, N)
% FUSE_INVERSE_COVARIANCE  Inverse-covariance weighted fusion of position estimates.
%
% fused = fuse_inverse_covariance(parts, N)
%
% Inputs:
%   parts - cell array of structs with fields x (Nx1), y (Nx1), cov (2x2xN)
%   N     - number of time steps
%
% Output:
%   fused - struct with x, y (Nx1) and cov (2x2xN)
%
% At each step, estimates that are NaN or have an ill-conditioned covariance
% are skipped, so the result degrades gracefully to whichever sources are
% available. For independent Gaussian estimates this is the minimum-variance
% linear combination: C = (sum C_i^-1)^-1, x = C * sum C_i^-1 x_i.
%
% Assumes the estimates are independent. (The Simulink est_x/est_y already
% contains AoA and RTT information, so fusing it with AoA/RTT again double
% counts; analyze_run warns about that.)

fused.x = nan(N, 1);
fused.y = nan(N, 1);
fused.cov = nan(2, 2, N);
for k = 1:N
    info = zeros(2, 2);
    vec = zeros(2, 1);
    used = 0;
    for i = 1:numel(parts)
        p = [parts{i}.x(k); parts{i}.y(k)];
        Ck = parts{i}.cov(:, :, k);
        if any(~isfinite(p)) || any(~isfinite(Ck(:))) || rcond(Ck) < 1e-10
            continue;
        end
        Ci = inv(Ck);
        info = info + Ci;
        vec = vec + Ci * p;
        used = used + 1;
    end
    if used > 0
        Cf = inv(info);
        s = Cf * vec;
        fused.x(k) = s(1);
        fused.y(k) = s(2);
        fused.cov(:, :, k) = Cf;
    end
end
end
