function rss_dBm = simulate_rss(anchor_pos, agent_pos, cfg, tech)
% SIMULATE_RSS  Received power [dBm] from one agent position to each anchor.
%
% rss_dBm = simulate_rss(anchor_pos, agent_pos, cfg)
% rss_dBm = simulate_rss(anchor_pos, agent_pos, cfg, tech)
%
% Inputs:
%   anchor_pos - Kx2 anchor positions [m]
%   agent_pos  - 1x2 or 2x1 [x y] [m]
%   cfg        - config struct (cfg.channel.(tech), cfg.noise_scale.rss)
%   tech       - 'wifi' (default) or 'ble'
%
% Output:
%   rss_dBm - Kx1 received power at each anchor [dBm]
%
% Log-distance path loss PL(d) = PL0 + 10 n log10(d/d0) with additive Gaussian
% noise (global RNG). Distance clamped to d0. For whole trajectories with
% seeded noise use simulate_scenario.

if nargin < 4 || isempty(tech), tech = 'wifi'; end
ch = cfg.channel.(tech);
agent_pos = agent_pos(:)';

K = size(anchor_pos, 1);
rss_dBm = zeros(K, 1);
for i = 1:K
    d = hypot(agent_pos(1) - anchor_pos(i, 1), agent_pos(2) - anchor_pos(i, 2));
    d = max(d, ch.d0_m);
    PL = ch.PL0_dB + 10 * ch.n * log10(d / ch.d0_m);
    rss_dBm(i) = ch.Ptx_dBm - PL + cfg.noise_scale.rss * ch.rss_std_dB * randn;
end
end
