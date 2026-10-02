function stats = compute_metrics(res, cfg)
% COMPUTE_METRICS  Print a localization accuracy table and return the stats.
%
% stats = compute_metrics(res, cfg)
%
% Inputs:
%   res - result struct from analyze_run (fields err, info)
%   cfg - config struct (target_error_m)
%
% Output:
%   stats - struct from compute_error_stats (one entry per method that has data)
%
% All numbers are aggregated over time from the instantaneous Euclidean error
% [m]. Methods that are disabled or produced no estimate are not listed.

stats = compute_error_stats(res.err, cfg);
info = res.info;

fprintf('\nLocalization accuracy (simulation), target %.2g m\n', cfg.target_error_m);
fprintf('%-26s %7s %7s %7s %7s %7s %9s\n', 'Method', 'Mean', 'Median', 'P90', 'Max', 'RMSE', '<=target');
for k = 1:numel(info.keys)
    key = info.keys{k};
    if ~isfield(stats, key), continue; end
    s = stats.(key);
    fprintf('%-26s %6.3f  %6.3f  %6.3f  %6.3f  %6.3f  %7.1f %%\n', ...
        info.names{k}, s.mean_err, s.median_err, s.p90_err, s.max_err, s.rmse_err, ...
        100 * s.frac_under_target);
end
fprintf('(errors in metres)\n');
end
