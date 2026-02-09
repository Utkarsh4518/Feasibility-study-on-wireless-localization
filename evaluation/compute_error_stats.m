function stats = compute_error_stats(results, cfg)
% COMPUTE_ERROR_STATS  Compute mean, median, max, std (and min) for all error vectors.
%
% stats = compute_error_stats(results, cfg)
%
% Inputs:
%   results - Struct with errors_smooth, errors_kf, errors_aoa, errors_rtt,
%             errors_fused (each is instantaneous Euclidean L2 error in [m], one per timestep).
%             Also: haveRTT, enable_rss, enable_aoa, enable_rtt
%   cfg     - Config struct (used to know which modalities are enabled)
%
% Output:
%   stats   - Struct with one field per method. Each field is a struct with:
%             mean_err, median_err, max_err, min_err, std_err (aggregated over time; all in [m]).
%             Methods: 'smooth_rss', 'kalman_rss', 'aoa_wls', 'rtt', 'fusion'

if nargin < 2 || isempty(cfg)
    cfg = struct('enable_rss', true, 'enable_aoa', true, 'enable_rtt', true);
end

stats = struct();

methods = {};
errs = {};

if cfg.enable_rss
    methods{end+1} = 'smooth_rss';   errs{end+1} = results.errors_smooth;
    methods{end+1} = 'kalman_rss';   errs{end+1} = results.errors_kf;
end
if cfg.enable_aoa
    methods{end+1} = 'aoa_wls';     errs{end+1} = results.errors_aoa;
end
if cfg.enable_rtt && results.haveRTT
    methods{end+1} = 'rtt';         errs{end+1} = results.errors_rtt;
end
methods{end+1} = 'fusion';
errs{end+1} = results.errors_fused;

for k = 1:numel(methods)
    e = errs{k}(:);
    e = e(isfinite(e));
    if isempty(e)
        stats.(methods{k}) = struct('mean_err', NaN, 'median_err', NaN, ...
            'max_err', NaN, 'min_err', NaN, 'std_err', NaN);
    else
        stats.(methods{k}) = struct(...
            'mean_err',   double(mean(e)), ...
            'median_err', double(median(e)), ...
            'max_err',    double(max(e)), ...
            'min_err',    double(min(e)), ...
            'std_err',    double(std(e, 'omitnan')));
    end
end
end
