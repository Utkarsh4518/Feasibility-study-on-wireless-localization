function [out, AoA_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y, cfg, tech)
% APPLYPATHLOSSWITHAOA  Simulate path loss and angle-of-arrival for one link.
%
% [out, AoA_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y)
% [out, AoA_deg] = applyPathLossWithAOA(..., cfg)
% [out, AoA_deg] = applyPathLossWithAOA(..., cfg, tech)
%
% Inputs:
%   tx_signal        - Transmitted signal (scalar or vector)
%   agent_x, agent_y - Agent position [m]
%   anchor_x, anchor_y - Anchor position [m]
%   cfg  - (optional) config struct; uses cfg.channel.(tech) and cfg.noise_scale.aoa
%   tech - (optional) 'wifi' (default) or 'ble'
%
% Outputs:
%   out     - Attenuated signal (same size as tx_signal)
%   AoA_deg - Angle of arrival [deg], 0--360, with additive Gaussian noise
%
% Without cfg the WiFi parameters of the Simulink chart
% applyPathLossWithAOA_WiFi are used: PL0 = 30 dB, n = 2.2, AoA noise 2 deg.
%
% Assumptions:
%   - Log-distance path loss; single slope; no multipath.
%   - AoA = atan2(dy,dx) plus Gaussian angle noise (global RNG).
%
% Limitations:
%   - One link only. For a whole scenario use simulate_scenario.

if nargin < 7 || isempty(tech)
    tech = 'wifi';
end
if nargin < 6 || isempty(cfg)
    d0 = 1;
    PL0 = 30;
    n   = 2.2;
    aoa_noise_std_deg = 2;
else
    ch = cfg.channel.(tech);
    d0 = ch.d0_m;
    PL0 = ch.PL0_dB;
    n   = ch.n;
    aoa_noise_std_deg = cfg.noise_scale.aoa * ch.aoa_std_deg;
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
