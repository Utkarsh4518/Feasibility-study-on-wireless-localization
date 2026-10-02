function stats = compute_error_stats(errs, cfg)
% COMPUTE_ERROR_STATS  Error statistics per method.
%
% stats = compute_error_stats(errs, cfg)
%
% Inputs:
%   errs - struct, one field per method key, each an N x 1 (or runs x N) array
%          of instantaneous Euclidean (L2) position errors [m]. Non-finite
%          entries are ignored; a method with no finite entry is omitted.
%   cfg  - config struct (target_error_m)
%
% Output:
%   stats - struct, one field per method, each a struct with
%             mean_err, median_err, p90_err, max_err, min_err, std_err,
%             rmse_err [m], frac_under_target (fraction of samples <= target),
%             n (number of samples)

if nargin < 2 || isempty(cfg) || ~isfield(cfg, 'target_error_m')
    target = 0.5;
else
    target = cfg.target_error_m;
end

stats = struct();
keys = fieldnames(errs);
for k = 1:numel(keys)
    e = errs.(keys{k});
    e = e(isfinite(e(:)));
    if isempty(e)
        continue;
    end
    s.mean_err = mean(e);
    s.median_err = median(e);
    s.p90_err = simple_percentile(e, 90);
    s.max_err = max(e);
    s.min_err = min(e);
    if numel(e) > 1
        s.std_err = std(e);
    else
        s.std_err = 0;
    end
    s.rmse_err = sqrt(mean(e .^ 2));
    s.frac_under_target = mean(e <= target);
    s.n = numel(e);
    stats.(keys{k}) = s;
end
end
