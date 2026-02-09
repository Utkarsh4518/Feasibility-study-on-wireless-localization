function [out, AoA_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y, cfg)
% APPLYPATHLOSSWITHAOA  Simulate path loss and angle-of-arrival for one link.
%
% [out, AoA_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y)
% [out, AoA_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y, cfg)
%
% Inputs:
%   tx_signal - Transmitted signal (scalar or vector)
%   agent_x, agent_y - Agent position [m]
%   anchor_x, anchor_y - Anchor position [m]
%   cfg       - (optional) Config struct. If omitted, uses defaults below.
%
% Outputs:
%   out     - Attenuated signal (same size as tx_signal)
%   AoA_deg - Angle of arrival [deg], 0--360, with additive Gaussian noise
%
% Assumptions:
%   - Log-distance path loss; single slope; no multipath.
%   - AoA = atan2(dy,dx) plus Gaussian angle noise (config or default 2 deg std).
%
% Limitations:
%   - One link only. For multiple anchors use simulate_rss and/or loop this.
%   - Defaults: path_loss_ref_dB=30, path_loss_exponent=2.7, noise_aoa_std_deg=2.

if nargin < 6 || isempty(cfg)
    d0 = 1;
    PL0 = 30;
    n   = 2.7;
    aoa_noise_std_deg = 2;
else
    d0 = cfg.path_loss_ref_dist_m;
    PL0 = cfg.path_loss_ref_dB;
    n   = cfg.path_loss_exponent;
    aoa_noise_std_deg = cfg.noise_aoa_std_deg;
end

d = sqrt((agent_x - anchor_x)^2 + (agent_y - anchor_y)^2);
d = max(d, d0);

PL  = PL0 + 10 * n * log10(d / d0);
attenuation = 10.^(-PL / 20);
out = tx_signal * attenuation;

dx = agent_x - anchor_x;
dy = agent_y - anchor_y;
AoA_rad = atan2(dy, dx);
AoA_rad_noisy = AoA_rad + deg2rad(randn * aoa_noise_std_deg);
AoA_deg = mod(rad2deg(AoA_rad_noisy), 360);
end
