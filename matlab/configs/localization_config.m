function cfg = localization_config()
% LOCALIZATION_CONFIG  Single configuration for the localization simulation.
%
% All tunable parameters live here. Experiments can be rerun by changing
% only this file or by loading a .mat config (see load_config, save_config).
% The same fields are used by python/locref.py, so a saved cfg.json from any
% run can be reloaded there.
%
% Usage:
%   cfg = localization_config();
%
% See also: load_config, save_config, validate_config, run_experiment,
%           run_simulated_experiment

% =========================================================================
% SIMULATION / MODEL
% =========================================================================
cfg.modelName = 'Localization_Ependorfv2';
cfg.simulinkDir = 'simulink';
% Fixed random seed for reproducible runs (set [] to leave RNG unchanged)
cfg.random_seed = 42;
% Save evaluation report to results/<timestamp>/ (report_run)
cfg.save_evaluation_results = true;

% =========================================================================
% ANCHOR GEOMETRY [m]
% =========================================================================
% 'model' = the three anchors hard-coded in Localization_Ependorfv2.slx
% (Constant blocks "Anchor k_X/Y"). A Simulink run reads the true values from
% the model (see sync_anchors_with_model), so the analysis cannot silently use
% different anchors than the simulation did. The pure-MATLAB simulator
% (run_simulated_experiment) uses cfg.anchor_pos as given; other layouts:
% see anchor_layouts().
cfg.anchor_layout = 'model';
cfg.anchor_pos = anchor_layouts(cfg.anchor_layout);

% =========================================================================
% SIGNAL SELECTION
% =========================================================================
cfg.enable_rss = true;
cfg.enable_aoa = true;
cfg.enable_rtt = true;
% BLE links in addition to WiFi for RSS and RTT
cfg.use_ble = true;
% BLE AoA (5 deg noise). Off by default: the Simulink logging only exports
% the WiFi AoA signals listed in aoa_names.
cfg.use_ble_aoa = false;

% Logged signal names in the Simulink model (must match the model)
cfg.rss_names = {'estRSS1','estRSS2','estRSS3','estmRSS4','estmRSS5','estmRSS6'};
cfg.aoa_names = {'AoA1_RX_wifi','AoA2_RX_wifi','AoA3_RX_wifi'};
cfg.rtt_names = {'RTT_WIFI1','RTT_WIFI2','RTT_WIFI3', ...
                 'RTT_BLE1','RTT_BLE2','RTT_BLE3'};
cfg.rx_signal_name = 'rxSignal1_WiFi';

% =========================================================================
% CHANNEL (per technology) -- values taken from the Simulink model charts
% applyPathLossWithAOA_WiFi / _BLE, so the MATLAB simulator and the model agree.
% =========================================================================
%   Ptx_dBm / PL0_dB / n / d0_m : log-distance path loss
%   rss_std_dB                   : RSS measurement noise
%   aoa_std_deg                  : angle-of-arrival noise
%   rtt_std_s                    : round-trip-time noise (1 ns ~ 0.15 m one-way)
cfg.channel.wifi = struct('Ptx_dBm', 0, 'PL0_dB', 30, 'n', 2.2, 'd0_m', 1, ...
    'rss_std_dB', 1.5, 'aoa_std_deg', 2, 'rtt_std_s', 1e-9);
cfg.channel.ble  = struct('Ptx_dBm', 0, 'PL0_dB', 50, 'n', 3.0, 'd0_m', 1, ...
    'rss_std_dB', 1.5, 'aoa_std_deg', 5, 'rtt_std_s', 5e-9);

% Multipliers on the noise stds above (1 = nominal). Used by sweeps.
cfg.noise_scale = struct('rss', 1, 'aoa', 1, 'rtt', 1);

% =========================================================================
% TRAJECTORY (pure-MATLAB simulator only; Simulink uses its own agent path)
% =========================================================================
% Piecewise-linear path at constant speed, sampled every dt seconds.
% The default stays inside the triangle spanned by the model anchors.
cfg.trajectory.waypoints = [0.8 0.8; 3.6 0.8; 0.8 3.6; 0.8 0.8];
cfg.trajectory.speed_mps = 0.5;
cfg.trajectory.dt = 0.2;

% =========================================================================
% FILTER PARAMETERS
% =========================================================================
% RSS smoothing: moving-average window length (trailing window = causal)
cfg.smooth_win = 5;
cfg.smooth_causal = true;
cfg.kf_dt_default = 1;             % fallback dt [s] if time vector unavailable

% Kalman filter (constant-velocity model) on RSS positions.
% kf_input 'raw' feeds the unsmoothed position with its own covariance (better:
% the filter does the smoothing); 'smoothed' reproduces the original smooth-then-
% filter chain, which adds lag and double-smooths.
cfg.kf_input = 'raw';
cfg.kf_sigma_a = 0.5;              % process noise std (acceleration) [m/s^2]
cfg.kf_R_floor_m2 = 0.05;          % added to the measurement covariance [m^2]
cfg.kf_R_fixed_m2 = 1.0;           % used when the RSS estimator gives no covariance
cfg.kf_chi2_gate = 9.21;           % 99% confidence, 2 DOF (outlier rejection)
cfg.kf_max_rejects = 5;            % re-initialise after this many consecutive rejections
cfg.kf_P0_diag = [25 4 25 4];      % initial state covariance diagonal

% Joint extended Kalman filter (RSS/RTT ranges + AoA bearings)
cfg.ekf_sigma_a = 0.5;
cfg.ekf_gate = 9;                  % scalar innovation gate (innov^2/S), ~3 sigma
cfg.ekf_P0_diag = [25 4 25 4];

% =========================================================================
% FUSION of the per-modality position estimates
% =========================================================================
% 'inverse_cov' : weight each estimate by the inverse of its covariance
% 'fixed'       : cfg.fusion_weight_kf * KF + (1 - w) * AoA (original behaviour)
cfg.fusion_method = 'inverse_cov';
cfg.fusion_weight_kf = 0.7;

% =========================================================================
% EVALUATION
% =========================================================================
cfg.target_error_m = 0.5;          % accuracy target used in plots / metrics

% =========================================================================
% PHYSICAL CONSTANTS
% =========================================================================
cfg.speed_of_light = 3e8;          % [m/s]
end
