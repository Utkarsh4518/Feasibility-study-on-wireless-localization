function meas = extract_simulink_measurements(out, cfg)
% EXTRACT_SIMULINK_MEASUREMENTS  Convert a Simulink run into the common meas struct.
%
% meas = extract_simulink_measurements(out, cfg)
%
% Inputs:
%   out - SimulationOutput from sim(cfg.modelName)
%   cfg - config struct (aoa_names, rtt_names)
%
% Output meas (same format as simulate_scenario):
%   t, true_x, true_y         ground truth from the model (index-aligned)
%   est_x, est_y              the model's own position estimate
%   aoa, rtt                  groups from the logged signals, or [] if a signal
%                             is missing
%   rss                       [] -- the logged RSS has no absolute calibration
%                             (amplitude of the TX generator is unknown to
%                             MATLAB), so RSS is represented by est_x/est_y
%   est_source                'simulink_combined'
%
% NOTE: est_x/est_y is the minimiser of a combined RSS + AoA + RTT objective
% (fminsearch in the LocalizationSolver chart), not an RSS-only estimate.
%
% Signals are aligned by index, truncated to the shortest, as before.

true_x = out.true_x(:);
true_y = out.true_y(:);
est_x  = out.est_x(:);
est_y  = out.est_y(:);
N = min([numel(true_x), numel(true_y), numel(est_x), numel(est_y)]);

meas.true_x = true_x(1:N);
meas.true_y = true_y(1:N);
meas.est_x = est_x(1:N);
meas.est_y = est_y(1:N);

t = [];
try
    t = out.tout(:);
catch
end
if numel(t) >= N
    meas.t = t(1:N);
else
    meas.t = (0:N - 1)' * cfg.kf_dt_default;
end

K = size(cfg.anchor_pos, 1);
meas.rss = [];
meas.aoa = read_group(out, cfg.aoa_names, N, 1:numel(cfg.aoa_names), false(1, numel(cfg.aoa_names)));
nRtt = numel(cfg.rtt_names);
half = nRtt / 2;
meas.rtt = read_group(out, cfg.rtt_names, N, [1:half, 1:half], [false(1, half), true(1, half)]);
meas.est_source = 'simulink_combined';
assert(K == half || isempty(meas.rtt), ...
    'extract_simulink_measurements:anchors', ...
    'cfg.rtt_names expects %d anchors but cfg.anchor_pos has %d.', half, K);
end

function g = read_group(out, names, N, anchor, is_ble)
L = numel(names);
val = nan(N, L);
for i = 1:L
    sig = getSignalIfExists(out, names{i});
    if isempty(sig)
        warning('localization:signal', 'Signal "%s" not found in the model output.', names{i});
        g = [];
        return;
    end
    d = sig.Values.Data(:);
    n = min(N, numel(d));
    val(1:n, i) = d(1:n);
end
g.val = val;
g.anchor = anchor;
g.is_ble = is_ble;
end
