function [x, y] = estimate_position_ls(distances, anchors)
% ESTIMATE_POSITION_LS  Least-squares position estimate from ranges to anchors.
%
% [x, y] = estimate_position_ls(distances, anchors)
%
% Inputs:
%   distances - Mx1 distances from agent to each anchor [m]
%   anchors   - Mx2 [x_i, y_i] anchor positions [m]; same order as distances
%
% Outputs:
%   x, y - Estimated agent position [m]
%
% Assumptions:
%   - 2D plane; distances are Euclidean (line-of-sight).
%   - Range errors are zero-mean (LS is optimal for Gaussian errors).
%   - At least 2 anchors; first anchor used as reference in linearization.
%
% Limitations:
%   - Not robust to outliers; a single bad range can bias the solution.
%   - Geometry (anchor arrangement) affects accuracy; poor geometry gives
%     large uncertainty. Does not return covariance.
%   - Linearized formulation; for very large range errors, iterative
%     refinement (e.g. Gauss-Newton) would be more accurate.

M = size(anchors, 1);
if M < 2
    error('estimate_position_ls: at least 2 anchors required.');
end

A = zeros(M-1, 2);
b = zeros(M-1, 1);
x1 = anchors(1, 1);
y1 = anchors(1, 2);

for i = 2:M
    xi = anchors(i, 1);
    yi = anchors(i, 2);
    A(i-1, :) = 2 * [xi - x1, yi - y1];
    b(i-1) = (distances(1)^2 - distances(i)^2) + (xi^2 - x1^2) + (yi^2 - y1^2);
end

sol = (A' * A) \ (A' * b);
x = sol(1);
y = sol(2);
end
