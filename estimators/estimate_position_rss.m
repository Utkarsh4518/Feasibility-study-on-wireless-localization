function [p, C] = estimate_position_rss(anchors, m, row, cfg)
% ESTIMATE_POSITION_RSS  RSS-only position: RSS -> ranges -> weighted LS.
%
% [p, C] = estimate_position_rss(anchors, m, row, cfg)
%
% Inputs:
%   anchors - Kx2 anchor positions [m]
%   m       - RSS measurement group (fields anchor, is_ble)
%   row     - 1xL RSS values [dBm] at one time step
%   cfg     - config struct (channel model used for ranging)
%
% Outputs:
%   p - 1x2 position; C - 2x2 covariance (see estimate_position_ranges)
%
% Ranging inverts the log-distance model of the matching technology
% (cfg.channel.wifi / .ble). The Simulink estimator chart uses one fixed set of
% parameters (PL0 = 44 dB, n = 1.9) for every link instead, which biases its
% BLE ranges; here the model is matched to the channel.

[r, s] = link_measurements(cfg, m, 'rss', row);
[p, C] = estimate_position_ranges(anchors(m.anchor, :), r, s);
end
