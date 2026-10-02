function q = simple_percentile(x, p)
% SIMPLE_PERCENTILE  Percentile with linear interpolation, ignoring NaN/Inf.
%
% q = simple_percentile(x, p)
%
% p in [0, 100]. Matches numpy.percentile's default (linear) method. Exists so
% the project needs no Statistics Toolbox (prctile).

x = sort(x(isfinite(x(:))));
n = numel(x);
if n == 0
    q = NaN;
    return;
end
pos = 1 + (n - 1) * p / 100;
lo = floor(pos);
hi = ceil(pos);
q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
