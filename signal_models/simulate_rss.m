function rss_dB = simulate_rss(anchor_pos, agent_pos, config)
% SIMULATE_RSS  Simulate RSS (received power in dBm) from agent to each anchor.
%
% rss_dB = simulate_rss(anchor_pos, agent_pos, config)
%
% Inputs:
%   anchor_pos - Nx2 array [x_i, y_i] of anchor positions [m]
%   agent_pos  - 1x2 or 2x1 [x, y] agent position [m]
%   config     - Struct with path_loss_ref_dB, path_loss_exponent,
%                path_loss_ref_dist_m, path_loss_tx_dBm, noise_sigma_rss_dB
%
% Output:
%   rss_dB - Nx1 received power at each anchor [dBm]
%
% Assumptions:
%   - Log-distance path loss: PL(d) = PL0 + 10*n*log10(d/d0).
%   - Free-space-like propagation; no multipath or shadowing.
%   - Additive Gaussian noise on RSS (dB) with std config.noise_sigma_rss_dB.
%   - 2D geometry; all positions in same plane.
%
% Limitations:
%   - Single slope (one path-loss exponent); real indoor channels may vary.
%   - No correlation between anchor noises; no temporal correlation.
%   - Distance clamped to d0 to avoid log(0).

agent_pos = agent_pos(:)';
d0 = config.path_loss_ref_dist_m;
PL0 = config.path_loss_ref_dB;
n   = config.path_loss_exponent;
Ptx = config.path_loss_tx_dBm;
sigma_dB = config.noise_sigma_rss_dB;

N = size(anchor_pos, 1);
rss_dB = zeros(N, 1);

for i = 1:N
    d = sqrt((agent_pos(1) - anchor_pos(i,1))^2 + (agent_pos(2) - anchor_pos(i,2))^2);
    d = max(d, d0);
    PL = PL0 + 10 * n * log10(d / d0);
    rss_dB(i) = Ptx - PL + sigma_dB * randn;
end
end
