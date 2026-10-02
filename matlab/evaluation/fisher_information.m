function J = fisher_information(cfg, px, py)
% FISHER_INFORMATION  2x2 Fisher information for the position at (px, py).
%
% J = fisher_information(cfg, px, py)
%
% Sums the information of every link enabled in cfg (single snapshot, no motion
% model):
%   range links (RTT, RSS):  (1/s^2) u u'   with u = unit vector anchor -> agent
%       RTT: s = c*sigma_t/2
%       RSS: s = d*ln(10)/(10 n)*sigma_dB   (equivalently
%            (lambda^2/sigma_dB^2) * (d d')/|d|^4 with lambda = 10 n/ln(10)),
%            with d clamped at d0 as in the channel model
%   bearing links (AoA):     (1/(d*sigma_theta)^2) v v'   with v perpendicular to u
%
% The same noise floors as link_measurements are applied only to RTT and AoA
% (RSS uses a 1e-9 m floor so the bound stays a pure physical limit).
%
% The earlier compute_crlb_over_time used lambda = 10/(ln(10) n) and divided by
% d^2 instead of d^4, which is not the Fisher information of the log-distance
% model.

A = cfg.anchor_pos;
ns = cfg.noise_scale;
c = cfg.speed_of_light;

rrTechs = {'wifi'};
if cfg.use_ble, rrTechs = {'wifi', 'ble'}; end
aoaTechs = {'wifi'};
if cfg.use_ble_aoa, aoaTechs = {'wifi', 'ble'}; end

J = zeros(2, 2);
for a = 1:size(A, 1)
    dx = px - A(a, 1);
    dy = py - A(a, 2);
    d = max(hypot(dx, dy), 1e-6);
    u = [dx; dy] / d;
    v = [-u(2); u(1)];
    for it = 1:numel(rrTechs)
        ch = cfg.channel.(rrTechs{it});
        if cfg.enable_rtt
            s = max(c * ns.rtt * ch.rtt_std_s / 2, 1e-3);
            J = J + (u * u') / s ^ 2;
        end
        if cfg.enable_rss
            % the channel clamps d at d0, so RSS carries no extra information closer than d0
            s = max(max(d, ch.d0_m) * log(10) / (10 * ch.n) * ns.rss * ch.rss_std_dB, 1e-9);
            J = J + (u * u') / s ^ 2;
        end
    end
    if cfg.enable_aoa
        for it = 1:numel(aoaTechs)
            ch = cfg.channel.(aoaTechs{it});
            s = max(deg2rad(ns.aoa * ch.aoa_std_deg), 1e-4);
            J = J + (v * v') / (d * s) ^ 2;
        end
    end
end
end
