function compute_metrics(results, cfg)
% COMPUTE_METRICS  Print localization accuracy sections for enabled modalities only.
%
% compute_metrics(results, cfg)
%
% Inputs:
%   results - Struct with errors_smooth, errors_kf, errors_aoa, errors_rtt, errors_fused
%             (each instantaneous Euclidean L2 error in [m]). Also enable_* / haveRTT.
%   cfg     - Config struct with enable_rss, enable_aoa, enable_rtt
%
% Printed stats are aggregated over time: mean, median, max, min, std of the instantaneous errors.

if nargin < 2 || isempty(cfg)
    cfg = struct('enable_rss', true, 'enable_aoa', true, 'enable_rtt', true);
end

if cfg.enable_rss
    print_accuracy_section('Smoothed RSS', results.errors_smooth);
    print_accuracy_section('Kalman Filtered RSS', results.errors_kf);
end
if cfg.enable_aoa
    print_accuracy_section('AoA WLS', results.errors_aoa);
end
if cfg.enable_rtt && results.haveRTT
    print_accuracy_section('RTT Trilateration', results.errors_rtt);
end
print_accuracy_section('Fusion', results.errors_fused);
end

function print_accuracy_section(label, errors)
e = errors(isfinite(errors(:)));
if isempty(e)
    fprintf('\n--- Localization Accuracy (%s) ---\n', label);
    fprintf('(no valid samples)\n');
    return;
end
fprintf('\n--- Localization Accuracy (%s) ---\n', label);
fprintf('Mean Error      : %.2f m\n', mean(e));
fprintf('Median Error    : %.2f m\n', median(e));
fprintf('Max Error       : %.2f m\n', max(e));
fprintf('Min Error       : %.2f m\n', min(e));
fprintf('Std Deviation   : %.2f m\n', std(e, 'omitnan'));
end
