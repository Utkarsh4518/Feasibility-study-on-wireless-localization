function meas = simulate_scenario(cfg, seed)
% SIMULATE_SCENARIO  Generate RSS / AoA / RTT measurements without Simulink.
%
% meas = simulate_scenario(cfg)
% meas = simulate_scenario(cfg, seed)
%
% Reproduces the channel of Localization_Ependorfv2.slx (log-distance path
% loss per technology, Gaussian noise on RSS, bearing and RTT) along the
% trajectory in cfg.trajectory, for any number of anchors in cfg.anchor_pos.
% Uses its own RandStream, so results do not depend on (or disturb) the global
% random state.
%
% Output meas (also the format produced by extract_simulink_measurements):
%   t, true_x, true_y     Nx1
%   rss, aoa, rtt         groups with fields
%                           val     NxL raw values (dBm, deg, s)
%                           anchor  1xL anchor index of each link
%                           is_ble  1xL true for BLE links
%   est_source            'rss_ls' (RSS-only estimate computed by analyze_run)
%
% Links are ordered [WiFi anchors 1..K, BLE anchors 1..K].

if nargin < 2 || isempty(seed)
    seed = cfg.random_seed;
end
if isempty(seed)
    rs = RandStream('mt19937ar', 'Seed', 'shuffle');
else
    rs = RandStream('mt19937ar', 'Seed', seed);
end

[t, tx, ty] = make_trajectory(cfg.trajectory);

rrTechs = {'wifi'};
if cfg.use_ble, rrTechs = {'wifi', 'ble'}; end
aoaTechs = {'wifi'};
if cfg.use_ble_aoa, aoaTechs = {'wifi', 'ble'}; end

meas.t = t;
meas.true_x = tx;
meas.true_y = ty;
meas.rss = make_group('rss', rrTechs, cfg, tx, ty, rs);
meas.aoa = make_group('aoa', aoaTechs, cfg, tx, ty, rs);
meas.rtt = make_group('rtt', rrTechs, cfg, tx, ty, rs);
meas.est_source = 'rss_ls';
end

function g = make_group(kind, techs, cfg, tx, ty, rs)
A = cfg.anchor_pos;
K = size(A, 1);
N = numel(tx);
ns = cfg.noise_scale;
L = numel(techs) * K;
g.val = zeros(N, L);
g.anchor = zeros(1, L);
g.is_ble = false(1, L);

l = 0;
for it = 1:numel(techs)
    isb = strcmp(techs{it}, 'ble');
    if isb
        ch = cfg.channel.ble;
    else
        ch = cfg.channel.wifi;
    end
    for a = 1:K
        l = l + 1;
        g.anchor(l) = a;
        g.is_ble(l) = isb;
        dx = tx - A(a, 1);
        dy = ty - A(a, 2);
        d = max(hypot(dx, dy), ch.d0_m);
        switch kind
            case 'rss'
                PL = ch.PL0_dB + 10 * ch.n * log10(d / ch.d0_m);
                g.val(:, l) = ch.Ptx_dBm - PL + ns.rss * ch.rss_std_dB * randn(rs, N, 1);
            case 'aoa'
                ang = atan2(dy, dx) + deg2rad(ns.aoa * ch.aoa_std_deg * randn(rs, N, 1));
                g.val(:, l) = mod(rad2deg(ang), 360);
            case 'rtt'
                g.val(:, l) = 2 * d / cfg.speed_of_light + ns.rtt * ch.rtt_std_s * randn(rs, N, 1);
        end
    end
end
end
