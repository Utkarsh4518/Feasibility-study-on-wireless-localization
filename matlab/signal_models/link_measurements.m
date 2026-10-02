function [val, sigma] = link_measurements(cfg, m, kind, row)
% LINK_MEASUREMENTS  Convert one time step of raw link data to ranges or bearings.
%
% [val, sigma] = link_measurements(cfg, m, kind, row)
%
% Inputs:
%   cfg  - config struct (channel, noise_scale, speed_of_light)
%   m    - measurement group struct: fields is_ble (1xL), anchor (1xL), val (NxL)
%   kind - 'rss' | 'rtt' | 'aoa'
%   row  - 1xL raw values at one time step (m.val(k,:))
%
% Outputs (both 1xL):
%   'rss' : val = range [m] from the log-distance model, sigma = range std [m]
%           (sigma_d = d*ln(10)/(10 n)*sigma_dB, floored at 0.2 m)
%   'rtt' : val = range [m] = rtt*c/2, sigma = c*sigma_t/2 [m] (floored at 1 mm)
%   'aoa' : val = bearing anchor->agent [rad], sigma = bearing std [rad]
%           (floored at 1e-4 rad)
%
% The floors keep weights finite when a noise scale is set to 0.

row = row(:)';
ns = cfg.noise_scale;
switch kind
    case 'rss'
        n    = channel_param(cfg, m.is_ble, 'n');
        PL0  = channel_param(cfg, m.is_ble, 'PL0_dB');
        Ptx  = channel_param(cfg, m.is_ble, 'Ptx_dBm');
        d0   = channel_param(cfg, m.is_ble, 'd0_m');
        sdB  = channel_param(cfg, m.is_ble, 'rss_std_dB');
        val  = d0 .* 10 .^ ((Ptx - PL0 - row) ./ (10 .* n));
        sigma = max(val .* log(10) ./ (10 .* n) .* ns.rss .* sdB, 0.2);
    case 'rtt'
        st    = channel_param(cfg, m.is_ble, 'rtt_std_s');
        val   = row .* cfg.speed_of_light ./ 2;
        sigma = max(cfg.speed_of_light .* ns.rtt .* st ./ 2, 1e-3);
    case 'aoa'
        sa    = channel_param(cfg, m.is_ble, 'aoa_std_deg');
        val   = deg2rad(row);
        sigma = max(deg2rad(ns.aoa .* sa), 1e-4);
    otherwise
        error('localization:link', 'Unknown link kind "%s".', kind);
end
end
