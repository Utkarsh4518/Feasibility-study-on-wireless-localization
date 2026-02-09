function cfg = localization_config()
% LOCALIZATION_CONFIG  Single configuration for the localization simulation.
%
% All tunable parameters live here. Experiments can be rerun by changing
% only this file or by loading a .mat config (see load_config, save_config).
%
% Usage:
%   cfg = localization_config();
%
% See also: load_config, save_config, run_experiment

% =========================================================================
% SIMULATION / MODEL
% =========================================================================
cfg.modelName = 'Localization_Ependorfv2';
cfg.simulinkDir = 'LocalizationRSSandsub';
% Fixed random seed for reproducible runs (set [] to leave RNG unchanged)
cfg.random_seed = 42;
% Save evaluation report to results/ with timestamp (run_evaluation_report)
cfg.save_evaluation_results = true;

% =========================================================================
% ANCHOR GEOMETRY [m] (must match Simulink model)
% =========================================================================
cfg.anchor_pos = [1,  3;
                  5,  7;
                 10, 11];
cfg.anchor_x = cfg.anchor_pos(:, 1)';
cfg.anchor_y = cfg.anchor_pos(:, 2)';

% =========================================================================
% SIGNAL SELECTION (enable flags and log names)
% =========================================================================
cfg.enable_rss = true;
cfg.enable_aoa = true;
cfg.enable_rtt = true;

cfg.rss_names = {'estRSS1','estRSS2','estRSS3','estmRSS4','estmRSS5','estmRSS6'};
cfg.aoa_names = {'AoA1_RX_wifi','AoA2_RX_wifi','AoA3_RX_wifi'};
cfg.rtt_names = {'RTT_WIFI1','RTT_WIFI2','RTT_WIFI3', ...
                 'RTT_BLE1','RTT_BLE2','RTT_BLE3'};
cfg.rx_signal_name = 'rxSignal1_WiFi';

% =========================================================================
% NOISE STATISTICS (for signal models and CRLB)
% =========================================================================
% RSS: std of RSS measurement noise [dB]
cfg.noise_sigma_rss_dB = 3;
% AoA: std of angle-of-arrival noise [deg]
cfg.noise_aoa_std_deg = 2;
% RTT: std of round-trip time noise [s] (optional; 0 = no additive noise in post-processing)
cfg.noise_rtt_std_s = 0;

% =========================================================================
% PATH LOSS / CHANNEL (used by applyPathLossWithAOA and CRLB)
% =========================================================================
cfg.path_loss_tx_dBm = 0;
cfg.path_loss_ref_dB = 30;
cfg.path_loss_exponent = 2.7;
cfg.path_loss_ref_dist_m = 1;

% =========================================================================
% FILTER PARAMETERS
% =========================================================================
% RSS smoothing: moving-average window length
cfg.smooth_win = 3;

% Kalman filter (constant-velocity model)
cfg.kf_dt_default = 1;              % fallback dt [s] if tout unavailable
cfg.kf_sigma_a = 0.5;              % process noise std (acceleration) [m/s^2]
cfg.kf_measurement_var_floor = 1;  % min R diagonal [m^2]
cfg.kf_P0_diag = [100 10 100 10];  % initial state covariance diagonal
cfg.kf_chi2_gate = 9.21;           % 95% confidence, 2 DOF (outlier rejection)
cfg.kf_fusion_alpha = 0.3;         % optional blend KF vs smooth (if used)

% =========================================================================
% FUSION (RSS-KF + AoA WLS weights when both are enabled)
% =========================================================================
cfg.fusion_weight_kf = 0.7;   % weight on Kalman estimate (1-cfg.fusion_weight_kf on AoA)

% =========================================================================
% PHYSICAL CONSTANTS
% =========================================================================
cfg.speed_of_light = 3e8;   % [m/s] for RTT to distance
end
