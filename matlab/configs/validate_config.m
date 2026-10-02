function cfg = validate_config(cfg)
% VALIDATE_CONFIG  Fail early on malformed configuration.
%
% cfg = validate_config(cfg)
%
% Throws an error with identifier 'localization:config' describing the first
% problem found. Returns cfg unchanged (kept as an output so calls can be
% chained: cfg = validate_config(load_config(...))).

chk(isstruct(cfg), 'cfg must be a struct.');

% Anchors
chk(isnumeric(cfg.anchor_pos) && ismatrix(cfg.anchor_pos) && ...
    size(cfg.anchor_pos, 2) == 2 && size(cfg.anchor_pos, 1) >= 2 && ...
    all(isfinite(cfg.anchor_pos(:))), ...
    'anchor_pos must be a finite Kx2 matrix with K >= 2.');
chk(size(unique(cfg.anchor_pos, 'rows'), 1) == size(cfg.anchor_pos, 1), ...
    'anchor_pos contains duplicate anchors.');

% Flags
flags = {'enable_rss', 'enable_aoa', 'enable_rtt', 'use_ble', 'use_ble_aoa', 'smooth_causal'};
for i = 1:numel(flags)
    chk(isscalar(cfg.(flags{i})) && (islogical(cfg.(flags{i})) || isnumeric(cfg.(flags{i}))), ...
        '%s must be a logical scalar.', flags{i});
end
chk(cfg.enable_rss || cfg.enable_aoa || cfg.enable_rtt, ...
    'At least one of enable_rss / enable_aoa / enable_rtt must be true.');

% Channel
techs = {'wifi', 'ble'};
for i = 1:numel(techs)
    ch = cfg.channel.(techs{i});
    chk(ch.n > 0 && ch.d0_m > 0, 'channel.%s: n and d0_m must be positive.', techs{i});
    chk(ch.rss_std_dB >= 0 && ch.aoa_std_deg >= 0 && ch.rtt_std_s >= 0, ...
        'channel.%s: noise stds must be non-negative.', techs{i});
end
ns = cfg.noise_scale;
chk(ns.rss >= 0 && ns.aoa >= 0 && ns.rtt >= 0, 'noise_scale entries must be >= 0.');
chk(cfg.speed_of_light > 0, 'speed_of_light must be positive.');

% Trajectory
tr = cfg.trajectory;
chk(size(tr.waypoints, 2) == 2 && size(tr.waypoints, 1) >= 2, ...
    'trajectory.waypoints must be Mx2 with M >= 2.');
chk(tr.speed_mps > 0 && tr.dt > 0, 'trajectory speed_mps and dt must be positive.');

% Filters
chk(cfg.smooth_win >= 1 && cfg.smooth_win == round(cfg.smooth_win), ...
    'smooth_win must be a positive integer.');
chk(cfg.kf_sigma_a > 0 && cfg.ekf_sigma_a > 0, 'kf_sigma_a / ekf_sigma_a must be positive.');
chk(cfg.kf_R_floor_m2 >= 0 && cfg.kf_R_fixed_m2 > 0, ...
    'kf_R_floor_m2 must be >= 0 and kf_R_fixed_m2 > 0.');
chk(cfg.kf_chi2_gate > 0 && cfg.ekf_gate > 0, 'Gates must be positive.');
chk(cfg.kf_max_rejects >= 1, 'kf_max_rejects must be >= 1.');
chk(numel(cfg.kf_P0_diag) == 4 && all(cfg.kf_P0_diag > 0), 'kf_P0_diag must have 4 positive entries.');
chk(numel(cfg.ekf_P0_diag) == 4 && all(cfg.ekf_P0_diag > 0), 'ekf_P0_diag must have 4 positive entries.');

chk(any(strcmp(cfg.kf_input, {'raw', 'smoothed'})), 'kf_input must be ''raw'' or ''smoothed''.');

% Fusion / evaluation
chk(any(strcmp(cfg.fusion_method, {'inverse_cov', 'fixed'})), ...
    'fusion_method must be ''inverse_cov'' or ''fixed''.');
chk(cfg.fusion_weight_kf >= 0 && cfg.fusion_weight_kf <= 1, ...
    'fusion_weight_kf must be in [0, 1].');
chk(cfg.target_error_m > 0, 'target_error_m must be positive.');
chk(isempty(cfg.random_seed) || (isscalar(cfg.random_seed) && cfg.random_seed >= 0 && ...
    cfg.random_seed == round(cfg.random_seed)), ...
    'random_seed must be empty or a non-negative integer.');
end

function chk(cond, msg, varargin)
if ~cond
    error('localization:config', msg, varargin{:});
end
end
