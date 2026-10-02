function info = method_info(est_source)
% METHOD_INFO  Registry of localization methods: keys, display names, colours.
%
% info = method_info()
% info = method_info(est_source)
%
% est_source - 'rss_ls' (default; RSS-only estimate computed by analyze_run) or
%              'simulink_combined' (est_x/est_y exported by the Simulink model,
%              which minimises an RSS + AoA + RTT objective, so it is *not*
%              RSS-only and is labelled accordingly).
%
% Fields:
%   keys    - cell array of method keys (also the field names in res.est / res.err)
%   names   - display names (same order)
%   colors  - Nx3 colour per method (Okabe-Ito, colour-blind safe)
%   markers - marker per method
%
% Colours are fixed per method so every figure uses the same colour for the
% same method.

if nargin < 1 || isempty(est_source)
    est_source = 'rss_ls';
end

info.keys = {'rss', 'rss_smooth', 'rss_kf', 'aoa', 'rtt', 'fusion', 'ekf'};
info.names = {'RSS (raw)', 'RSS smoothed', 'RSS + Kalman', 'AoA WLS', ...
              'RTT trilateration', 'Fusion (inv-cov)', 'EKF (joint)'};
if strcmp(est_source, 'simulink_combined')
    info.names(1:3) = {'Model est. (RSS+AoA+RTT)', 'Model est. smoothed', 'Model est. + Kalman'};
end
info.colors = [0.50 0.50 0.50;     % rss        grey
               0.34 0.71 0.91;     % rss_smooth sky blue
               0.00 0.62 0.45;     % rss_kf     bluish green
               0.84 0.37 0.00;     % aoa        vermillion
               0.00 0.45 0.70;     % rtt        blue
               0.80 0.47 0.65;     % fusion     reddish purple
               0.00 0.00 0.00];    % ekf        black
info.markers = {'o', 's', '^', 'd', 'v', 'p', 'h'};
end
