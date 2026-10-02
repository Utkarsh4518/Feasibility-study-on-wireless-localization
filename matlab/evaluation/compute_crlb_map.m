function Z = compute_crlb_map(cfg, xs, ys)
% COMPUTE_CRLB_MAP  Position-error lower bound over a grid (geometry map).
%
% Z = compute_crlb_map(cfg, xs, ys)
%
% xs (1xNx), ys (1xNy) - grid coordinates [m]
% Z (Ny x Nx)          - sqrt(trace(J^-1)) [m] at each grid point; NaN where
%                        the geometry is singular.
%
% Shows where the anchor layout supports accurate localization and where it
% does not (anchor line, outside the anchor hull). See compute_crlb_over_time.

Z = nan(numel(ys), numel(xs));
for i = 1:numel(ys)
    for j = 1:numel(xs)
        J = fisher_information(cfg, xs(j), ys(i));
        if rcond(J) > 1e-12
            Z(i, j) = sqrt(trace(inv(J)));
        end
    end
end
end
